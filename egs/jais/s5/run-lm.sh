

if [ $stage -le 2 ]; then

	echo
	echo "===== LANGUAGE MODEL CREATION ====="
	echo "===== MAKING lm.arpa ====="
	echo

	loc=`which ngram-count`;
	if [ -z $loc ]; then
	   if uname -a | grep 64 >/dev/null; then
		   sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
	   else
			   sdir=$KALDI_ROOT/tools/srilm/bin/i686
	   fi
	   if [ -f $sdir/ngram-count ]; then
			   echo "Using SRILM language modelling tool from $sdir"
			   export PATH=$PATH:$sdir
	   else
			   echo "SRILM toolkit is probably not installed.
				   Instructions: tools/install_srilm.sh"
			   exit 1
	   fi

	fi

	local=data/local
	mkdir $local/tmp
	ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount \
	  -text $local/corpus.txt -lm $local/tmp/lm.arpa
	ngram -prune-lowprobs -lm $local/tmp/lm.arpa -write-lm $local/tmp/lm-pruned.arpa

	ngram-count -order 2 -write-vocab $local/tmp/vocab-full-sm.txt -wbdiscount \
	  -text $local/corpus.txt -lm $local/tmp/lm-sm.arpa
	ngram -prune-lowprobs -lm $local/tmp/lm-sm.arpa -write-lm $local/tmp/lm-sm-pruned.arpa


fi

if [ $stage -le 3 ]; then
	echo
	echo "===== MAKING G.fst ====="
	echo

	lang=data/lang
	arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang/words.txt \ 
	  $local/tmp/lm-pruned.arpa $lang/G.fst

	lang_sm=data/lang-sm
	arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang_sm/words.txt \ 
	  $local/tmp/lm-sm-pruned.arpa $lang/G.fst
fi