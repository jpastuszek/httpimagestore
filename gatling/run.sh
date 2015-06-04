CLASS=$1
shift
$GATLING_HOME/bin/gatling.sh \
	--data-folder ~/Documents/test_data \
	--results-folder `pwd`/results \
    --bodies-folder `pwd`/bodies \
    --simulations-folder `pwd`/simulations \
	--simulation $CLASS \
	$@
