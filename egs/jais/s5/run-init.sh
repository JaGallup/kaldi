if [ $stage -le 0 ]; then
	# Making spk2utt files
	utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
	utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
fi

if [ $stage -le 1 ]; then

	echo
	echo "===== FEATURES EXTRACTION ====="
	echo

	rm -r mfcc exp/make_mfcc

	# Making feats.scp files
	mfccdir=mfcc
	# Uncomment and modify arguments in scripts below if you have any problems with data sorting
	# utils/validate_data_dir.sh data/train     # script for checking prepared data - here: for data/train directory
	# utils/fix_data_dir.sh data/train          # tool for data proper sorting if needed - here: for data/train directory
	steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
	steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir

	# Making cmvn.scp files
	steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
	steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

fi


# Needs to be prepared by hand (or using self written scripts):
#
# spk2gender  [<speaker-id> <gender>]
# wav.scp     [<uterranceID> <full_path_to_audio_file>]
# text           [<uterranceID> <text_transcription>]
# utt2spk     [<uterranceID> <speakerID>]
# corpus.txt  [<text_transcription>]


if [ $stage -le 1 ]; then

	echo
	echo "===== PREPARING LANGUAGE DATA ====="
	echo

	# Needs to be prepared by hand (or using self written scripts):
	#
	# lexicon.txt           [<word> <phone 1> <phone 2> ...]
	# nonsilence_phones.txt    [<phone>]
	# silence_phones.txt    [<phone>]
	# optional_silence.txt  [<phone>]

	# Preparing language data
	utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang

fi
