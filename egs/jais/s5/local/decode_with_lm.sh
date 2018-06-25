#!/bin/bash

. ./path.sh
. ./cmd.sh

nj=4
arpa=false

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 5 ]; then
  echo "Usage: decode_with_lm.sh <lang-dir> <graph-dir> <data-dir> <decode-dir>"
  echo " e.g.: decode_with_lm.sh data/lang_a exp/tri3/graph data/test data/tri3/decode_lang_a"
  echo "Options: "
  echo "  --arpa <arpa-file>                  # default false. Expexts G.fst in <lang-dir>"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --nj <num-job>                                 # number of parallel jobs to run."
  exit 1;
fi

lang_dir="${$1%/}"
graph_dir="${$2%/}"
data_dir="${$3%/}"
decode_dir="${$4%/}"

if [ -e $arpa ]; then
	arpa2fst --disambig-symbol=#0 --read-symbol-table="$lang_dir/words.txt" \
		     "$arpa" "$lang_dir/G.fst"
fi

utils/mkgraph.sh "$lm" "$model" "$graph_dir";
steps/decode.sh --cmd "$cmd" --nj $nj "$graph_dir" "$test" "$decode_dir";
