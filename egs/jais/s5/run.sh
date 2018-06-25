#!/bin/bash

. ./path.sh
. ./cmd.sh

nj=4         # number of parallel jobs
nj_decode=4 # number of parallel jobs used for decoding
lm_order=4   # language model order (n-gram quantity)
stage=-100
stage=4
train=data/train
test=data/test
lang=data/lang

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh
[[ $# -ge 1 ]] && { echo "Wrong arguments!"; exit 1; }


if [ $stage -le 1 ]; then

	echo
	echo "===== MONO TRAINING ====="
	echo

	steps/train_mono.sh --nj $nj --cmd "$train_cmd" --totgauss 4000 "$train" "$lang" exp/mono 
fi

if [ $stage -le 2 ]; then

	echo
	echo "===== TRI1 (first triphone pass) TRAINING ====="
	echo

	steps/align_si.sh --nj $nj --cmd "$train_cmd" "$train" "$lang" exp/mono exp/mono_ali

	steps/train_deltas.sh --cmd "$train_cmd" 3200 30000 "$train" "$lang" exp/mono_ali exp/tri1
fi


if [ $stage -le 3 ]; then
	echo
	echo "==== TRI2 (delta + delta - delta) ===="
	echo 
	
	steps/align_si.sh --nj $nj --cmd "$train_cmd" "$train" "$lang" exp/tri1 exp/tri1_ali;
	
	steps/train_deltas.sh --cmd "$train_cmd" 4000 70000 "$train" "$lang" exp/tri1_ali exp/tri2a;
fi

if [ $stage -le 4 ]; then
	echo
	echo "==== TRI2 (LDA + MLLT) ===="
	echo 
	
	steps/align_si.sh --nj $nj --cmd "$train_cmd" "$train" "$lang" exp/tri2a exp/tri2a_ali;
	
	#Options: --splice-opts "--left-context=5 --right-context=5"
	steps/train_lda_mllt.sh --cmd "$train_cmd" 6000 140000 "$train" "$lang" exp/tri2_ali exp/tri2b;
fi

if [ $stage -le 5 ]; then
	echo
	echo "==== TRI3 (LDA + MLLT + SAT) ===="
	echo 

	steps/align_fmllr.sh  --nj $nj --cmd "$train_cmd" "$train" "$lang" exp/tri2b exp/tri2b_ali;
	
	steps/train_sat.sh --cmd "$train_cmd" 11500 200000 "$train" "$lang" exp/tri2b_ali exp/tri3;

	utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph;

	steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nj_decode exp/tri3/graph \
						  "$test" exp/tri3/decode;	

fi

if [ $stage -le 6 ]; then
  # MMI training starting from the LDA+MLLT+SAT systems
  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" "$train" "$lang" exp/tri3 exp/tri3_ali;

  steps/make_denlats.sh --nj $nj --cmd "$decode_cmd" \
                        --config conf/decode.config --transform-dir exp/tri3_ali \
                        "$train" "$lang" exp/tri3 exp/tri3_denlats;

fi

if [ $stage -le 7 ]; then
	echo "Train MMI"
  # 4 iterations of MMI seems to work well overall. The number of iterations is
  # used as an explicit argument even though train_mmi.sh will use 4 iterations by
  # default.
  num_mmi_iters=4
  steps/train_mmi.sh --cmd "$decode_cmd" \
                     --boost 0.1 --num-iters $num_mmi_iters \
                     "$train" "$lang" exp/tri3_{ali,denlats} exp/tri3_mmi;

  for iter in 1 2 3 4; do
    
      graph_dir=exp/tri3/graph
      decode_dir=exp/tri3_mmi/decode_${iter}.mdl
      steps/decode.sh --nj $nj --cmd "$decode_cmd" \
                      --config conf/decode.config --iter $iter \
                      --transform-dir exp/tri3/decode_mmi \
                      $graph_dir data/test $decode_dir;
  done
fi


if [ $stage -le 8 ]; then
  # Now do fMMI+MMI training
  steps/train_diag_ubm.sh --silence-weight 0.5 --nj $nj --cmd "$train_cmd" \
                          700 "$train" "$lang" exp/tri3_ali exp/tri3_dubm;

  steps/train_mmi_fmmi.sh --learning-rate 0.005 \
                          --boost 0.1 --cmd "$train_cmd" \
                          "$train" "$lang" exp/tri3_ali exp/tri3_dubm \
                          exp/tri3_denlats exp/tri3_fmmi;

  for iter in 4 5 6 7 8; do
    
      graph_dir=exp/tri3/graph
      decode_dir=exp/tri3_fmmi/decode_it${iter}
      steps/decode_fmmi.sh --nj $nj_decode --cmd "$decode_cmd" --iter $iter \
                           --transform-dir exp/tri3/decode \
                           --config conf/decode.config $graph_dir data/train $decode_dir;
  done
fi

echo
echo "===== run.sh script is finished ====="
echo
