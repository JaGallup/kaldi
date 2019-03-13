#!/bin/bash

echo "$0 $@"

if [ $# -ne 3 ]; then
	echo "This script creates a folder with everything needed"
	echo "for decoding using https://github.com/gooofy/py-kaldi-asr"
	echo "Usage: pack_mdl.sh <graph-dir> <online-dir> <dest-dir>"
	exit 1;
fi

graph_dir=$1
online_dir=$2
target_dir=$3

mkdir -p $target_dir

cp -r $graph_dir $target_dir
cp -r $online_dir/conf $target_dir
cp -r $online_dir/ivector_extractor $target_dir
cp $online_dir/final.mdl $target_dir

echo "#!/bin/bash

if [ \$# -ne 1 ]; then
	echo 'Fix the config paths'
	echo 'Usage: fix_config_path.sh <full-model-path>'
	exit 1;
fi

model_dir=\$1

sed -i -e \"s|--splice-config=.*\/conf\/splice.conf|--splice-config=\$model_dir\/conf\/splice.conf|\" conf/ivector_extractor.conf 
sed -i -e \"s|--cmvn-config=.*\/conf\/online_cmvn.conf|--cmvn-config=\$model_dir\/conf\/online_cmvn.conf|\" conf/ivector_extractor.conf 
sed -i -e \"s|--lda-matrix=.*\/ivector_extractor\/final.mat|--lda-matrix=\$model_dir\/ivector_extractor\/final.mat|\" conf/ivector_extractor.conf 
sed -i -e \"s|--global-cmvn-stats=.*\/ivector_extractor\/global_cmvn.stats|--global-cmvn-stats=\$model_dir\/ivector_extractor\/global_cmvn.stats|\" conf/ivector_extractor.conf 
sed -i -e \"s|--diag-ubm=.*\/ivector_extractor\/final.dubm|--diag-ubm=\$model_dir\/ivector_extractor\/final.dubm|\" conf/ivector_extractor.conf 
sed -i -e \"s|--ivector-extractor=.*\/ivector_extractor\/final.ie|--ivector-extractor=\$model_dir\/ivector_extractor\/final.ie|\" conf/ivector_extractor.conf 
sed -i -e \"s|--mfcc-config=.*\/conf\/mfcc.conf|--mfcc-config=\$model_dir\/conf\/mfcc.conf|\" conf/online.conf
sed -i -e \"s|--ivector-extraction-config=.*\/conf\/ivector_extractor.conf|--ivector-extraction-config=\$model_dir\/conf\/ivector_extractor.conf|\" conf/online.conf

" > $target_dir/fix_config_path.sh
