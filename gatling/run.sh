# This script will run load test
# It will download Gatling and 126MiB of test images
#
# Assuming:
#	* HTTPThumbnailer is checked out beside of httpimagestore
#	* upload images are stored in /tmp/images (created automatically)
#
set -e

GATLING_HOME=gatling-charts-highcharts-bundle-2.1.6
set_up_gatling() {
	[[ -d gatling-charts-highcharts-bundle-2.1.6 ]] || (
		wget --continue https://repo1.maven.org/maven2/io/gatling/highcharts/gatling-charts-highcharts-bundle/2.1.6/gatling-charts-highcharts-bundle-2.1.6-bundle.zip
		unzip gatling-charts-highcharts-bundle-2.1.6-bundle.zip
		rm -f gatling-charts-highcharts-bundle-2.1.6-bundle.zip
	)
}

set_up_image_db() {
	[[ -d 101_ObjectCategories ]] || (
		wget --continue http://www.vision.caltech.edu/Image_Datasets/Caltech101/101_ObjectCategories.tar.gz
		tar xf 101_ObjectCategories.tar.gz
		rm -f 101_ObjectCategories.tar.gz
	)

	[[ -f index.csv ]] || (
		echo "Indexing test data files"
		echo "file_name" > index.csv
		find 101_ObjectCategories -type f | rev | sort | rev >> index.csv
	)
}

set_up_gatling
set_up_image_db

finish() {
	echo
	echo "HTTPThumbnailer stats:"
	curl -s 127.0.0.1:3150/stats
	echo
	echo "HTTPImageStore stats:"
	curl -s 127.0.0.1:3050/stats
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

RUN_TAG=`date -u +%Y%m%d_%H%M%S`-`git describe --always`
CLASS=$1
if [[ -z "$CLASS" ]]; then
   CLASS=LoadTest
else
	shift
fi

$GATLING_HOME/bin/gatling.sh \
	--data-folder ~/Documents/test_data \
	--results-folder `pwd`/results \
    --bodies-folder `pwd`/bodies \
    --simulations-folder `pwd`/simulations \
	--simulation $CLASS \
	--output-name "$CLASS-$RUN_TAG" \
	$@
