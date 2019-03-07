#!/bin/bash

echo "$0 $@"

if [ $# -ne 4 ]; then
	echo "This script compiles and prepares a language model for Kaldi"
	echo "Usage: mklm.sh <corpus> <phones> <lexicon> <dest-dir>"
	echo "<corpus> normalized text for language modeling"
	echo "<phones> contains all phonemes in the language"
	echo "<lexicon> phonetic transcriptions for all words in the language"
	exit 1;
fi

corpus=$1
phones=$2
lexicon=$3
dir=$4

ngram_order=3

mkdir -p $dir/local/dict

cp $corpus $dir/local/corpus.txt
if [ -d data/train ]; then
	# Cut utternace id from training data and add to corpus
	cat data/train/text | cut -f 1 -d ' ' --complement >> $dir/local/corpus.txt
fi

cp $phones $dir/local/dict/nonsilence_phones.txt
cp $lexicon $dir/local/lm.lex
gawk -F '\t' '{print $1}' $dir/local/lm.lex > $dir/local/lm.voc

printf "sil\noov\n" > $dir/local/dict/silence_phones.txt
printf "sil\n" > $dir/local/dict/optional_silence.txt


cp $lexicon $dir/local/dict/lexicon.txt
sed -i "s/\t/ /g" $dir/local/dict/lexicon.txt
cat <(printf "!sil sil\n<unk> oov\n") $dir/local/dict/lexicon.txt > $dir/local/dict/lexicon.txt.tmp
mv $dir/local/dict/lexicon.txt{.tmp,}

ngram-count -order $ngram_order -kndiscount{1,2,3} -text $dir/local/corpus.txt -lm $dir/local/lm.arpa -vocab $dir/local/lm.voc -limit-vocab

if [ -f "utils/prepare_lang.sh" ]; then
	# Simlink utils from kaldi or run sparetly
	utils/prepare_lang.sh $dir/local/dict "<unk>" $dir/local/lang $dir/lang
	arpa2fst --disambig-symbol=#0 --read-symbol-table=$dir/lang/words.txt $dir/local/lm.arpa $dir/lang/G.fst
fi
