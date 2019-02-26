#!/bin/bash

stage=0
train_discriminative=false  # by default, don't do the GMM-based discriminative
                            # training.

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh


# This setups was modified from egs/sebd/s5c
# and adapted to the malromur corpus http://www.malfong.is/?pg=malromur

set -e # exit on error

if [ $stage -le 7 ]; then
  # Now make MFCC features.
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.
  mfccdir=mfcc
  for x in train eval2000 test; do
    steps/make_mfcc.sh --nj 50 --cmd "$train_cmd" \
                       data/$x exp/make_mfcc/$x $mfccdir
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
    utils/fix_data_dir.sh data/$x
  done
fi

if [ $stage -le 8 ]; then
  # Now-- there are 260k utterances (313hr 23min), and we want to start the
  # monophone training on relatively short utterances (easier to align), but not
  # only the shortest ones (mostly uh-huh).  So take the 100k shortest ones, and
  # then take 30k random utterances from those (about 12hr)
  utils/subset_data_dir.sh --shortest data/train 100000 data/train_100kshort
  utils/subset_data_dir.sh data/train_100kshort 30000 data/train_30kshort

  # Take the first 100k utterances (just under half the data); we'll use
  # this for later stages of training.
  utils/subset_data_dir.sh --first data/train 100000 data/train_100k_dups
  utils/data/remove_dup_utts.sh 200 data/train_100k_dups data/train_100k  # 110hr
fi

if [ $stage -le 9 ]; then
  ## Starting basic training on MFCC features
  steps/train_mono.sh --nj 30 --cmd "$train_cmd" \
                      data/train_30kshort data/lang exp/mono
fi

if [ $stage -le 10 ]; then
  steps/align_si.sh --nj 30 --cmd "$train_cmd" \
                    data/train_100k_nodup data/lang exp/mono exp/mono_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
                        3200 30000 data/train_100k data/lang exp/mono_ali exp/tri1

  graph_dir=exp/tri1/graph
  $train_cmd $graph_dir/mkgraph.log \
             utils/mkgraph.sh data/lang exp/tri1 $graph_dir
  steps/decode_si.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
                     $graph_dir data/eval2000 exp/tri1/decode_eval2000
fi


if [ $stage -le 11 ]; then
  steps/align_si.sh --nj 30 --cmd "$train_cmd" \
                    data/train_100k_nodup data/lang exp/tri1 exp/tri1_ali

  steps/train_deltas.sh --cmd "$train_cmd" \
                        4000 70000 data/train_100k data/lang exp/tri1_ali exp/tri2

  graph_dir=exp/tri2/graph
  $train_cmd $graph_dir/mkgraph.log \
             utils/mkgraph.sh data/lang_nosp_sw1_tg exp/tri2 $graph_dir
  steps/decode.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
                    $graph_dir data/eval2000 exp/tri2/decode_eval2000
fi

if [ $stage -le 12 ]; then
  # From now, we start using all of the data (except some duplicates of common
  # utterances, which don't really contribute much).
  steps/align_si.sh --nj 30 --cmd "$train_cmd" \
                    data/train data/lang exp/tri2 exp/tri2_ali

  # Do another iteration of LDA+MLLT training, on all the data.
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
                          6000 140000 data/train data/lang exp/tri2_ali exp/tri3

  graph_dir=exp/tri3/graph
  $train_cmd $graph_dir/mkgraph.log \
             utils/mkgraph.sh data/lang exp/tri3 $graph_dir
  steps/decode.sh --nj 30 --cmd "$decode_cmd" --config conf/decode.config \
                  $graph_dir data/eval2000 exp/tri3/decode_eval2000
fi


if [ $stage -le 14 ]; then
  # Train tri4, which is LDA+MLLT+SAT, on all the data.
  steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
                       data/train data/lang exp/tri3 exp/tri3_ali


  steps/train_sat.sh  --cmd "$train_cmd" \
                      11500 200000 data/train_nodup data/lang exp/tri3_ali exp/tri4

  graph_dir=exp/tri4/graph
  $train_cmd $graph_dir/mkgraph.log \
             utils/mkgraph.sh data/lang exp/tri4 $graph_dir
  steps/decode_fmllr.sh --nj 30 --cmd "$decode_cmd" \
                        --config conf/decode.config \
                        $graph_dir data/eval2000 exp/tri4/decode_eval2000
  # Will be used for confidence calibration example,
  steps/decode_fmllr.sh --nj 30 --cmd "$decode_cmd" \
                        $graph_dir data/train_dev exp/tri4/decode_dev
fi
