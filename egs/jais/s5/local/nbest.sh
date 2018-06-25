. ./cmd.sh
. ./path.sh


lattice-to-nbest --n=10 --acoustic-scale=0.5 "ark:gunzip -c exp16/tri3a/decode_foo/lat.1.gz|" ark:/tmp/nbest.lats

lattice-best-path --word-symbol-table=exp16/tri3a/graph_gallup_min/words.txt ark:/tmp/nbest.lats ark,t:/tmp/lbp.tra

utils/int2sym.pl -f 2- exp16/tri3a/graph_gallup_min/words.txt /tmp/lbp.tra
