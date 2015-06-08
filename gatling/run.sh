#
# this will run LoadTest
# assuming:
#	* uploade images are stored in /tmp/images (created automatically)
#	* HTTPThumbnailer is checked out beside of httpimagestore
#
set -e

finish() {
	kill `cat /tmp/httpthumbnailer.pid`
	kill `cat /tmp/httpimagestore.pid`
}

trap finish EXIT

start_thumbnailer() {
	echo "Starting HTTPThumbnailer..."
	(
		cd ../../httpthumbnailer
		bin/httpthumbnailer --listener 127.0.0.1:3150 --pid-file /tmp/httpthumbnailer.pid
		while ! curl -s -o /dev/null 127.0.0.1:3150/; do sleep 1; echo .; done
	)
}

start_imagestore() {
	echo "Starting HTTPImageStore..."
	(
		cd ..
		bin/httpimagestore --listener 127.0.0.1:3050 --pid-file /tmp/httpimagestore.pid gatling/httpimagestore.conf
		while ! curl -s -o /dev/null 127.0.0.1:3050/; do sleep 1; echo .; done
	)
}

start_thumbnailer
start_imagestore

# create storage dir
[[ -d "/tmp/images" ]] || mkdir "/tmp/images"

CLASS=$1
shift
$GATLING_HOME/bin/gatling.sh \
	--data-folder ~/Documents/test_data \
	--results-folder `pwd`/results \
    --bodies-folder `pwd`/bodies \
    --simulations-folder `pwd`/simulations \
	--simulation $CLASS \
	$@
