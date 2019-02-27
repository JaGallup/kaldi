# Author: Þorsteinn Daði Gunnarsson
#
# Prepares speech data from malromur http://www.malfong.is/?pg=malromur
# and creates train and test sets
# Usage: ./local/malromur_generate_data.sh <path-to-malromur>
#
# Get malromur_prep_data.sh from https://github.com/cadia-lvl/ice-asr/blob/master/ice-kaldi/s5/
# and put in local folder

folder=correct
datadir=data/all

malromur_dir=$1; shift

awk -F ',' -v folder="$folder" 'BEGIN { OFS = "\t" } $8 == folder {print $1".wav", $2, $3, $4, $5, $6, $7, "vorbis", "16000", "1", "Vorbis"}' $malromur_dir/info.txt > $malromur_dir/wav_info.txt

./local/malromur_prep_data.sh $malromur_dir/$folder $malromur_dir/wav_info.txt $datadir

utils/utt2spk_to_spk2utt.pl < $datadir/utt2spk > $datadir/spk2utt
utils/validate_data_dir.sh --no-feats $datadir || utils/fix_data_dir.sh $datadir

# The malromur corpus is ordered by speakers so to get a split with minimal
# speaker overlap (maximum one speaker in both sets)
# we can just split without shuffling the data
utils/subset_data_dir.sh --first $datadir 90000 data/train
n=$[`cat $datadir/wav.scp | wc -l` - 90000]
echo $n
utils/subset_data_dir.sh --last $datadir $n data/test
utils/subset_data_dir.sh data/test 2000 data/eval2000


