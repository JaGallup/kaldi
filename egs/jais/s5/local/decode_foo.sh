#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# Begin configuration section.
transform_dir=   # this option won't normally be used, but it can be used if you want to
                 # supply existing fMLLR transforms when decoding.
iter=
stage=0
nj=1
cmd=run.pl
max_active=7000
beam=13.0
lattice_beam=6.0
acwt=0.083333 # note: only really affects pruning (scoring is on lattices).
num_threads=1 # if >1, will use gmm-latgen-faster-parallel
parallel_opts=  # ignored now.
decode_extra_opts=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 0 ]; then
   echo "Usage: steps/decode.sh [options] <graph-dir> <data-dir> <decode-dir>"
   echo "... where <decode-dir> is assumed to be a sub-directory of the directory"
   echo " where the model is."
   echo "e.g.: steps/decode.sh exp/mono/graph_tgpr data/test_dev93 exp/mono/decode_dev93_tgpr"
   echo ""
   echo "This script works on CMN + (delta+delta-delta | LDA+MLLT) features; it works out"
   echo "what type of features you used (assuming it's one of these two)"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --iter <iter>                                    # Iteration of model to test."
   echo "                                                   # specify the final.alimdl)"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --transform-dir <trans-dir>                      # dir to find fMLLR transforms "
   echo "  --acwt <float>                                   # acoustic scale used for lattice generation "
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   echo "  --parallel-opts <opts>                           # ignored now, present for historical reasons."
   exit 1;
fi


#graphdir=$1
#data=$2
#dir=$3
modeldir=exp16/tri4a
graphdir=$modeldir/graph
model=$modeldir/final.mdl
data=foo
dir=$modeldir/decode_foo
srcdir=`dirname $dir`; # The model directory is one level up from decoding directory.
sdata=$data/split$nj;

mkdir -p $dir/log
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs

if [ -z "$model" ]; then # if --model <mdl> was not specified on the command line...
  if [ -z $iter ]; then model=$srcdir/final.mdl;
  else model=$srcdir/$iter.mdl; fi
fi

if [ $(basename $model) != final.alimdl ] ; then
  # Do not use the $srcpath -- look at the path where the model is
  if [ -f $(dirname $model)/final.alimdl ] && [ -z "$transform_dir" ]; then
    echo -e '\n\n'
    echo $0 'WARNING: Running speaker independent system decoding using a SAT model!'
    echo $0 'WARNING: This is OK if you know what you are doing...'
    echo -e '\n\n'
  fi
fi

for f in $sdata/1/feats.scp $sdata/1/cmvn.scp $model $graphdir/HCLG.fst; do
  [ ! -f $f ] && echo "decode.sh: no such file $f" && exit 1;
done

if [ -f $srcdir/final.mat ]; then feat_type=lda; else feat_type=delta; fi
echo "decode.sh: feature type is $feat_type";

splice_opts=`cat $srcdir/splice_opts 2>/dev/null` # frame-splicing options.
cmvn_opts=`cat $srcdir/cmvn_opts 2>/dev/null`
delta_opts=`cat $srcdir/delta_opts 2>/dev/null`

case $feat_type in
  delta) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/1/utt2spk scp:$sdata/1/cmvn.scp scp:$sdata/1/feats.scp ark:- | add-deltas $delta_opts ark:- ark:- |";;
  lda) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/1/utt2spk scp:$sdata/1/cmvn.scp scp:$sdata/1/feats.scp ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $srcdir/final.mat ark:- ark:- |";;
  *) echo "Invalid feature type $feat_type" && exit 1;
esac

if [ $stage -le 0 ]; then
  if [ -f "$graphdir/num_pdfs" ]; then
    [ "`cat $graphdir/num_pdfs`" -eq `am-info --print-args=false $model | grep pdfs | awk '{print $NF}'` ] || \
      { echo "Mismatch in number of pdfs with $model"; exit 1; }
  fi
  gmm-latgen-faster --max-active=$max_active --beam=$beam --lattice-beam=$lattice_beam \
    --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt $decode_extra_opts \
    $model $graphdir/HCLG.fst "$feats" ark:$dir/lat.1 || exit 1;
fi

lattice-best-path --word-symbol-table=$graphdir/words.txt ark:$modeldir/decode_foo/lat.1 ark,t:$modeldir/decode_foo/foo.tra

utils/int2sym.pl -f 2- $graphdir/words.txt $modeldir/decode_foo/foo.tra > /tmp/tra.txt

exit 0;
