#!/usr/bin/env bash
# API smoke test against the seed data (docs/api.md). Run from Git Bash:
#   bash backend/tests/smoke.sh [base-url]
# Default base is the local XAMPP junction. Registers one throwaway user per run.

BASE="${1:-http://localhost/rob/backend/api}"
SEED="$(dirname "$0")/../uploads/seed"
JAR_VIEWER=$(mktemp); JAR_OWNER=$(mktemp); JAR_NEW=$(mktemp); JAR_OWNER2=$(mktemp)
# A text file named .jpg: the API must check the bytes, not the name.
# Kept next to this script (curl on Windows cannot read Git Bash's /tmp).
FAKE="$(dirname "$0")/not-a-photo.jpg"; echo 'not really a photo' > "$FAKE"
trap 'rm -f "$JAR_VIEWER" "$JAR_OWNER" "$JAR_NEW" "$JAR_OWNER2" "$FAKE"' EXIT
PASS=0; FAIL=0

# upload <label> <expected status> <path> <cookie jar> <grep pattern> <file>...
upload() {
  local label=$1 want=$2 path=$3 jar=$4 pattern=$5; shift 5
  local args=(-s -o /tmp/rob_body -w '%{http_code}' -b "$jar" -c "$jar")
  for f in "$@"; do args+=(-F "photos[]=@$f"); done
  # extra form fields (caption, room_tag, is_hidden) from $UPLOAD_FIELDS
  for kv in $UPLOAD_FIELDS; do args+=(-F "$kv"); done
  local got; got=$(curl "${args[@]}" "$BASE/$path")
  if [ "$got" = "$want" ] && grep -q -- "$pattern" /tmp/rob_body; then
    PASS=$((PASS + 1)); echo "  ok   $got POST $path  ($label)"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL $got (want $want, body ~ $pattern) POST $path  ($label)"
    head -c 300 /tmp/rob_body; echo
  fi
}

# Prints the first value of "key": in the last response
last() { grep -o "\"$1\":[0-9]*" /tmp/rob_body | head -1 | cut -d: -f2; }

# check <label> <expected status> <method> <path> [json body] [cookie jar] [grep pattern]
check() {
  local label=$1 want=$2 method=$3 path=$4 body=$5 jar=$6 pattern=$7
  local args=(-s -o /tmp/rob_body -w '%{http_code}' -X "$method" "$BASE/$path")
  [ -n "$jar" ] && args+=(-b "$jar" -c "$jar")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  local got; got=$(curl "${args[@]}")
  if [ "$got" = "$want" ] && { [ -z "$pattern" ] || grep -q -- "$pattern" /tmp/rob_body; }; then
    PASS=$((PASS + 1)); echo "  ok   $got $method $path  ($label)"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL $got (want $want${pattern:+, body ~ $pattern}) $method $path  ($label)"
    head -c 300 /tmp/rob_body; echo
  fi
}

echo "Router"
check 'unknown route'        404 GET    'nope'
check 'wrong method'         405 PATCH  'properties'
check 'guest cannot book'    401 POST   'appointments' '{}'

echo "Session (guest)"
check 'guest is null'        200 GET    'session' '' '' '"data":null'
check 'bad login'            401 POST   'session' '{"email":"sarah@example.com","password":"wrong"}'
check 'empty login'          401 POST   'session' '{"email":"nope"}' '' 'Invalid email or password'
check 'bad json'             400 POST   'session' '{oops'

echo "Register"
EMAIL="smoke$(date +%s)@example.com"
check 'register viewer'      201 POST   'users' "{\"full_name\":\"Smoke Test\",\"email\":\"$EMAIL\",\"password\":\"Password123\",\"role\":\"viewer\"}" "$JAR_NEW" '"role":"viewer"'
check 'logged in after'      200 GET    'session' '' "$JAR_NEW" "$EMAIL"
check 'duplicate email'      422 POST   'users' "{\"full_name\":\"Smoke Test\",\"email\":\"$EMAIL\",\"password\":\"Password123\",\"role\":\"viewer\"}" '' 'already registered'
check 'owner needs phone'    422 POST   'users' '{"full_name":"No Phone","email":"np@example.com","password":"Password123","role":"owner"}' '' '"phone"'
check 'weak password'        422 POST   'users' '{"full_name":"Weak","email":"weak@example.com","password":"short","role":"viewer"}' '' '"password"'
check 'logout'               204 DELETE 'session' '' "$JAR_NEW"
check 'logged out'           200 GET    'session' '' "$JAR_NEW" '"data":null'

echo "Profile"
check 'guest cannot edit'    401 PATCH  'me' '{"full_name":"X Y"}'
check 'remember me cookie'   200 POST   'session' "{\"email\":\"$EMAIL\",\"password\":\"Password123\",\"remember\":true}" "$JAR_NEW"
grep -q 'ROB_SESSION' "$JAR_NEW" && awk '$6=="ROB_SESSION" && $5>0 {f=1} END {exit !f}' "$JAR_NEW"   && { PASS=$((PASS + 1)); echo '  ok   remembered cookie has an expiry'; }   || { FAIL=$((FAIL + 1)); echo '  FAIL remembered cookie has no expiry'; }
check 'rename'               200 PATCH  'me' '{"full_name":"Smoke Renamed"}' "$JAR_NEW" '"full_name":"Smoke Renamed"'
check 'session sees rename'  200 GET    'session' '' "$JAR_NEW" 'Smoke Renamed'
check 'viewer phone optional' 200 PATCH 'me' '{"phone":""}' "$JAR_NEW" '"phone":null'
check 'bad name + phone'     422 PATCH  'me' '{"full_name":"A","phone":"012-345"}' "$JAR_NEW" '"phone"'
check 'me wrong method'      405 GET    'me'

echo "Properties (guest)"
check 'list'                 200 GET    'properties' '' '' '"total"'
check 'filter + sort'        200 GET    'properties?listing_type=rent&city=Kuala%20Lumpur&sort=price_asc&per_page=5' '' '' '"per_page":5'
check 'search q'             200 GET    'properties?q=condo' '' '' '"data":\['
check 'unknown sort = newest' 200 GET    'properties?sort=random' '' '' '"total"'
check 'compare ids'          200 GET    'properties?ids=1,2,3' '' '' '"property_id":2'
check 'detail hides phone'   200 GET    'properties/1' '' '' '"phone":null'
check 'two property types'   200 GET    'properties?property_type=condo,house&per_page=48' '' '' '"property_type":"house"'
check 'missing property'     404 GET    'properties/99999'
check 'cities'               200 GET    'cities' '' '' '"listing_count"'
check 'map bounds'           200 GET    'map?north=3.25&south=3.05&east=101.8&west=101.6' '' '' '"latitude"'
check 'map needs bounds'     422 GET    'map?north=3' '' '' '"south"'
check 'map south > north'    422 GET    'map?north=3&south=4&east=101&west=100'
check 'mine needs login'     401 GET    'me/properties'

echo "Viewer"
check 'login viewer'         200 POST   'session' '{"email":"sarah@example.com","password":"Password123!"}' "$JAR_VIEWER" '"role":"viewer"'
check 'detail shows phone'   200 GET    'properties/1' '' "$JAR_VIEWER" '"phone":"6'
check 'mine is owner-only'   403 GET    'me/properties' '' "$JAR_VIEWER"

echo "Likes"
check 'guest cannot like'    401 PUT    'me/likes/2'
check 'like'                 200 PUT    'me/likes/2' '' "$JAR_VIEWER" '"liked":true'
check 'like again is fine'   200 PUT    'me/likes/2' '' "$JAR_VIEWER" '"liked":true'
check 'card shows liked'     200 GET    'properties/2' '' "$JAR_VIEWER" '"liked_by_me":true'
check 'my likes list'        200 GET    'me/likes?per_page=48' '' "$JAR_VIEWER" '"property_id":2,'
check 'unlike'               200 DELETE 'me/likes/2' '' "$JAR_VIEWER" '"liked":false'
check 'unlike again is fine' 200 DELETE 'me/likes/2' '' "$JAR_VIEWER" '"liked":false'
check 'like missing listing' 404 PUT    'me/likes/99999' '' "$JAR_VIEWER"
check 'likes paged'          200 GET    'me/likes?per_page=2' '' "$JAR_VIEWER" '"per_page":2'

echo "Owner"
check 'login owner'          200 POST   'session' '{"email":"aisha@example.com","password":"Password123!"}' "$JAR_OWNER" '"role":"owner"'
check 'my listings'          200 GET    'me/properties' '' "$JAR_OWNER" '"total"'
check 'own listing: no like' 403 PUT    'me/likes/1' '' "$JAR_OWNER" 'your own listing'
check 'card is_mine'         200 GET    'properties?ids=1' '' "$JAR_OWNER" '"is_mine":true'
check 'owner likes others'   200 PUT    'me/likes/9' '' "$JAR_OWNER" '"liked":true'
check 'owner unlikes others' 200 DELETE 'me/likes/9' '' "$JAR_OWNER" '"liked":false'
check 'owner keeps phone'    422 PATCH  'me' '{"phone":""}' "$JAR_OWNER" '"phone"'

echo "Owner listings"
LISTING='{"title":"Smoke test condo","description":"A listing made by the smoke test, deleted at the end.","listing_type":"rent","property_type":"condo","price":2500,"bedrooms":2,"bathrooms":1,"parking_spaces":1,"floor_area_sqm":80,"is_furnished":true,"address":"Jalan Ujian 1","city":"Kuching","state":"Sarawak","postcode":"93350","latitude":1.53,"longitude":110.34'
check 'viewer cannot create' 403 POST   'properties' "$LISTING}" "$JAR_VIEWER"
check 'create: validation'   422 POST   'properties' '{"title":"Flat","price":0,"latitude":3}' "$JAR_OWNER" '"description"'
check 'create'               201 POST   'properties' "$LISTING}" "$JAR_OWNER" '"is_mine":true'
NEW_ID=$(last property_id)
check 'starts available'     200 GET    "properties/$NEW_ID" '' '' '"status":"available"'
upload 'add 2 photos'        201 "properties/$NEW_ID/images" "$JAR_OWNER" '"image_id"' "$SEED/condo.jpg" "$SEED/kitchen.jpg"
IMG_A=$(grep -o '"image_id":[0-9]*' /tmp/rob_body | sed -n 1p | cut -d: -f2)
IMG_B=$(grep -o '"image_id":[0-9]*' /tmp/rob_body | sed -n 2p | cut -d: -f2)
NEW_FILE=$(grep -o '"file_path":"[^"]*' /tmp/rob_body | sed -n 1p | cut -d'"' -f4)
[ -f "$(dirname "$0")/../$NEW_FILE" ] && { PASS=$((PASS + 1)); echo '  ok   photo saved on disk'; } || { FAIL=$((FAIL + 1)); echo "  FAIL photo not on disk: $NEW_FILE"; }
upload 'not an image'        422 "properties/$NEW_ID/images" "$JAR_OWNER" 'not a JPEG' "$FAKE"
BIG="$(dirname "$0")/too-big.jpg"; head -c 2200000 /dev/urandom > "$BIG"
upload 'over 2 MB'           422 "properties/$NEW_ID/images" "$JAR_OWNER" 'larger than 2 MB' "$BIG"
rm -f "$BIG"
upload 'other owner upload'  403 "properties/$NEW_ID/images" "$JAR_VIEWER" 'error' "$SEED/condo.jpg"
check 'reorder'              200 PUT    "properties/$NEW_ID/images" "{\"order\":[$IMG_B,$IMG_A]}" "$JAR_OWNER" "\"image_id\":$IMG_B,"
check 'cover follows order'  200 GET    "properties?ids=$NEW_ID" '' '' "\"cover_image\":\"uploads/$NEW_ID/"
check 'reorder needs all'    422 PUT    "properties/$NEW_ID/images" "{\"order\":[$IMG_B]}" "$JAR_OWNER" '"order"'
UPLOAD_FIELDS="room_tag=kitchen caption=Renovated_kitchen"
upload 'upload with details'  201 "properties/$NEW_ID/images" "$JAR_OWNER" '"created":\[' "$SEED/kitchen.jpg"
UPLOAD_FIELDS=""
IMG_C=$(grep -o '"created":\[[0-9]*' /tmp/rob_body | grep -o '[0-9]*$')
grep -q "\"image_id\":$IMG_C,[^}]*\"room_tag\":\"kitchen\"" /tmp/rob_body && { PASS=$((PASS + 1)); echo '  ok   new photo saved with its room tag'; } || { FAIL=$((FAIL + 1)); echo '  FAIL room tag not saved on upload'; }
UPLOAD_FIELDS="room_tag=garage"
upload 'bad room tag'        422 "properties/$NEW_ID/images" "$JAR_OWNER" '"room_tag"' "$SEED/kitchen.jpg"
UPLOAD_FIELDS=""
check 'guest edits photo'    401 PATCH  "images/$IMG_C" '{"caption":"x"}'
check 'viewer edits photo'   403 PATCH  "images/$IMG_C" '{"caption":"x"}' "$JAR_VIEWER"
check 'caption + tag'        200 PATCH  "images/$IMG_C" '{"caption":"Open kitchen with island","room_tag":"dining"}' "$JAR_OWNER" '"room_tag":"dining"'
check 'caption too long'     422 PATCH  "images/$IMG_C" "{\"caption\":\"$(printf 'x%.0s' $(seq 1 151))\"}" "$JAR_OWNER" '"caption"'
check 'hide the cover'       200 PATCH  "images/$IMG_B" '{"is_hidden":true}' "$JAR_OWNER" '"is_hidden":true'
check 'owner still sees it'  200 GET    "properties/$NEW_ID" '' "$JAR_OWNER" "\"image_id\":$IMG_B,"
check 'public: hidden gone'  200 GET    "properties/$NEW_ID" '' ''
grep -q "\"image_id\":$IMG_B," /tmp/rob_body && { FAIL=$((FAIL + 1)); echo '  FAIL hidden photo shown to the public'; } || { PASS=$((PASS + 1)); echo '  ok   hidden photo not shown to the public'; }
check 'cover skips hidden'   200 GET    "properties?ids=$NEW_ID" '' '' "\"cover_image\":\"uploads/$NEW_ID/"
grep -q "$(grep -o '"file_path":"[^"]*' <<< "$(curl -s -b "$JAR_OWNER" "$BASE/properties/$NEW_ID")" | sed -n 1p | cut -d'"' -f4)\"" /tmp/rob_body && { FAIL=$((FAIL + 1)); echo '  FAIL cover is the hidden photo'; } || { PASS=$((PASS + 1)); echo '  ok   cover is the first shown photo'; }
check 'show it again'        200 PATCH  "images/$IMG_B" '{"is_hidden":false}' "$JAR_OWNER" '"is_hidden":false'
check 'delete photo'         204 DELETE "images/$IMG_A" '' "$JAR_OWNER"
[ ! -f "$(dirname "$0")/../$NEW_FILE" ] && { PASS=$((PASS + 1)); echo '  ok   photo file removed'; } || { FAIL=$((FAIL + 1)); echo '  FAIL photo file still on disk'; }
check 'replace (PUT)'        200 PUT    "properties/$NEW_ID" "$LISTING,\"title\":\"Smoke test condo, renamed\",\"status\":\"available\"}" "$JAR_OWNER" 'renamed'
check 'PUT needs status'     422 PUT    "properties/$NEW_ID" "$LISTING}" "$JAR_OWNER" '"status"'
check 'mark rented (PATCH)'  200 PATCH  "properties/$NEW_ID" '{"status":"rented"}' "$JAR_OWNER" '"status":"rented"'
check 'PATCH status only'    422 PATCH  "properties/$NEW_ID" '{"status":"sold","title":"x"}' "$JAR_OWNER" '"status"'
check 'rented hidden in search' 200 GET "properties?q=Smoke%20test%20condo" '' '' '"total":0'
check 'still in my listings' 200 GET    'me/properties?per_page=48' '' "$JAR_OWNER" "\"property_id\":$NEW_ID,"
check 'login 2nd owner'      200 POST   'session' '{"email":"jonathan@example.com","password":"Password123!"}' "$JAR_OWNER2"
check 'not your listing'     403 PATCH  "properties/$NEW_ID" '{"status":"available"}' "$JAR_OWNER2"
check 'cannot delete others' 403 DELETE "properties/$NEW_ID" '' "$JAR_OWNER2"
check 'delete listing'       204 DELETE "properties/$NEW_ID" '' "$JAR_OWNER"
check 'gone'                 404 GET    "properties/$NEW_ID"
[ ! -d "$(dirname "$0")/../uploads/$NEW_ID" ] && { PASS=$((PASS + 1)); echo '  ok   upload folder removed'; } || { FAIL=$((FAIL + 1)); echo '  FAIL upload folder left behind'; }

echo "Viewing days"
DAY=$(date -d '+40 days' +%F); PAST=$(date -d '-1 day' +%F)
check 'free days of listing' 200 GET    'properties/1/slots' '' '' '"viewing_time":"11:00"'
check 'slots: no listing'    404 GET    'properties/99999/slots'
check 'viewer has no days'   403 GET    'me/slots' '' "$JAR_VIEWER"
check 'my days'              200 GET    'me/slots' '' "$JAR_OWNER" '"is_booked":true'
check 'day in the past'      422 POST   'me/slots' "{\"viewing_date\":\"$PAST\",\"viewing_time\":\"14:00\"}" "$JAR_OWNER" '"viewing_date"'
check 'time out of hours'    422 POST   'me/slots' "{\"viewing_date\":\"$DAY\",\"viewing_time\":\"21:30\"}" "$JAR_OWNER" '"viewing_time"'
check 'add a day'            201 POST   'me/slots' "{\"viewing_date\":\"$DAY\",\"viewing_time\":\"14:00\"}" "$JAR_OWNER" '"is_booked":false'
SLOT_ID=$(last slot_id)
check 'one viewing per day'  409 POST   'me/slots' "{\"viewing_date\":\"$DAY\",\"viewing_time\":\"09:00\"}" "$JAR_OWNER" 'already have a viewing'

echo "Appointments"
check 'own listing: no book' 422 POST   'appointments' "{\"slot_id\":$SLOT_ID,\"property_id\":2}" "$JAR_OWNER" 'your own listing'
check 'wrong owner day'      422 POST   'appointments' "{\"slot_id\":$SLOT_ID,\"property_id\":9}" "$JAR_VIEWER" '"slot_id"'
check 'book'                 201 POST   'appointments' "{\"slot_id\":$SLOT_ID,\"property_id\":2,\"message\":\"Smoke test booking\"}" "$JAR_VIEWER" '"status":"pending"'
APPT_ID=$(last appointment_id)
check 'day is now taken'     409 POST   'appointments' "{\"slot_id\":$SLOT_ID,\"property_id\":2}" "$JAR_NEW" 'just booked'
check 'no double booking'    409 POST   'appointments' "{\"slot_id\":3,\"property_id\":2}" "$JAR_VIEWER" 'already have a viewing booked'
check 'booked day hidden'    200 GET    'properties/2/slots' '' ''
grep -q "\"slot_id\":$SLOT_ID," /tmp/rob_body && { FAIL=$((FAIL + 1)); echo '  FAIL booked day still offered'; } || { PASS=$((PASS + 1)); echo '  ok   booked day no longer offered'; }
check 'cannot delete booked' 409 DELETE "me/slots/$SLOT_ID" '' "$JAR_OWNER" 'booked'
check 'my upcoming'          200 GET    'me/appointments?as=viewer&when=upcoming' '' "$JAR_VIEWER" "\"appointment_id\":$APPT_ID,"
check 'owner inbox + counts' 200 GET    'me/appointments?as=owner&status=pending' '' "$JAR_OWNER" '"counts":{"pending"'
check 'viewer is not owner'  403 GET    'me/appointments?as=owner' '' "$JAR_VIEWER"
check 'viewer cannot confirm' 403 PATCH "appointments/$APPT_ID" '{"status":"confirmed"}' "$JAR_VIEWER"
check 'other owner: no'      403 PATCH  "appointments/$APPT_ID" '{"status":"confirmed"}' "$JAR_OWNER2"
check 'owner confirms'       200 PATCH  "appointments/$APPT_ID" '{"status":"confirmed"}' "$JAR_OWNER" '"status":"confirmed"'
check 'no decline after'     409 PATCH  "appointments/$APPT_ID" '{"status":"declined"}' "$JAR_OWNER" 'already confirmed'
check 'owner cannot cancel'  403 PATCH  "appointments/$APPT_ID" '{"status":"cancelled"}' "$JAR_OWNER"
check 'viewer cancels'       200 PATCH  "appointments/$APPT_ID" '{"status":"cancelled"}' "$JAR_VIEWER" '"status":"cancelled"'
check 'day free again'       200 GET    'properties/2/slots' '' '' "\"slot_id\":$SLOT_ID,"
check 'in past tab'          200 GET    'me/appointments?as=viewer&when=past&per_page=48' '' "$JAR_VIEWER" "\"appointment_id\":$APPT_ID,"
check 'book again (other)'   201 POST   'appointments' "{\"slot_id\":$SLOT_ID,\"property_id\":2}" "$JAR_NEW" '"status":"pending"'
APPT2=$(last appointment_id)
check 'mark listing rented'  200 PATCH  'properties/2' '{"status":"rented"}' "$JAR_OWNER" '"status":"rented"'
check 'request declined'     200 GET    'me/appointments?as=viewer&when=past&per_page=48' '' "$JAR_NEW" "\"appointment_id\":$APPT2,\"status\":\"declined\""
check 'rented: no days'      200 GET    'properties/2/slots' '' '' '"data":\[\]'
check 'available again'      200 PATCH  'properties/2' '{"status":"available"}' "$JAR_OWNER" '"status":"available"'
check 'remove the day'       204 DELETE "me/slots/$SLOT_ID" '' "$JAR_OWNER"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
