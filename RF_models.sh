#!/bin/bash

#Making working directory with Date

if [ "$1" == "-h" ]; then
  echo "Usage: `basename $0` [-h]"
  echo "RF_models.sh takes five arguments"
  echo "See example script below:"
  echo "\t\t./RF_models.sh train_posset.csv train_negset.csv testset.csv RF_models_workingdir_name cdr3only[true/fasle]"
  echo "\t\ttrain_posset.csv ==> file name of postive training set"
  echo "\t\ttrain_negset.csv ==> file name of negative training set"
  echo "\t\tRF_models_workingdir_name ==> working directory where intermediary and results file will be stored. "
  echo "\t\tcdr3only[true/fasle] ==> if true then pipeline will be run for cdr3 region only, if false then pipeline will be run for all cdr (1,2,3) regions"
  echo "\t\tRF predictions will be stored in RF_models_workingdir_name/RFtestingset_scores.txt"
  exit 0
fi

pos="$PWD/$1"
neg="$PWD/$2"
testset="$PWD/$3"
cdr3_only=$5

if [ "$cdr3_only" == "true" ]; then
        dir="$4_cdr3only"
        if [ -d "$dir" ]; then rm -Rf $dir; fi 
        mkdir $dir
        #step 1
        cd $dir
        date
        python ../RF_models/_1_create_kmer_dicts1.py generate loc_3mer.p \
               --inputs $pos $neg \
                --output_names pos_3mer neg_3mer \
                --length_dependent_trimming True \
                --kmer_size 3

        mkdir models_pos
        mkdir models_neg

        date
        python ../RF_models/_1b_remove_chains.py loc_3mer.p pos_3mer.npy models_pos/
        date
        python ../RF_models/_1b_remove_chains.py loc_3mer.p neg_3mer.npy models_neg/

        mkdir bins
	nline_pos=$(wc -l < $pos)
	nlines_neg=$(wc -l < $neg)
	echo $((nlines_neg / nline_pos))
	n_bins=$((nlines_neg / nline_pos))
	n_bins=$(($n_bins))
        for i in $(seq $n_bins);
        do
        date
        python ../RF_models/_3_random_forest.py \
                ./models_pos/only_cd3r_obj.npy \
                ./models_neg/only_cd3r_obj.npy \
                --runs 1 \
                --n_estimators 15 \
                --do_imbalance_match \
                --split_num $i \
                --min_samples_leaf 1 \
                --save_model \
                --model_name ./bins/model_trees_$i.p

        done

        #create python object of the testing set. 

        python ../RF_models/_1_create_kmer_dicts1.py encode loc_3mer.p \
                --inputs $testset \
                --output_names RFtestingset \
                --use_cdr3_length False \
                --length_dependent_trimming True \
                --kmer_size 3

        mkdir models_test

        python ../RF_models/_1b_remove_chains.py loc_3mer.p RFtestingset.npy models_test/

        #run prediction script using RF trees created in the earlier step. 

        python ../RF_models/_4_apply_split_RFs.py $PWD/bins model_trees $PWD/models_test/only_cd3r_obj.npy $4_RFtestingset_scores.txt

fi

if [ "$cdr3_only" == "false" ] ; then
	echo "creating $4_allcdrs"
        dir="$4_allcdrs"
        if [ -d "$dir" ]; then rm -Rf $dir; fi
        mkdir $dir

        #step 1
	echo "step 1, creating python object using input data"
        cd $dir
        date
        python ../RF_models/_1_create_kmer_dicts1.py generate loc_3mer.p \
               --inputs $pos $neg \
                --output_names pos_3mer neg_3mer \
                --length_dependent_trimming True \
                --kmer_size 3
	
	echo "step 2, making bins, each bin will have training tree"
        mkdir bins
 	nline_pos=$(wc -l < $pos)
        nlines_neg=$(wc -l < $neg)
        echo $((nlines_neg / nline_pos))
        n_bins=$((nlines_neg / nline_pos))
	n_bins=$(($n_bins))
	for i in $(seq $n_bins);
        do
        date
        python ../RF_models/_3_random_forest.py \
                pos_3mer.npy \
                neg_3mer.npy \
                --runs 1 \
                --n_estimators 15 \
                --do_imbalance_match \
                --split_num $i \
                --min_samples_leaf 1 \
                --save_model \
                --model_name ./bins/model_trees_$i.p

        done
	
	echo "creating python object of the testing set."
        #create python object of the testing set. 

        python ../RF_models/_1_create_kmer_dicts1.py encode loc_3mer.p \
                --inputs $testset \
                --output_names RFtestingset \
                --use_cdr3_length False \
                --length_dependent_trimming True \
                --kmer_size 3

	echo "running prediction script using RF trees created in step 2"

        #run prediction script using RF trees created in the earlier step. 

        python ../RF_models/_4_apply_split_RFs.py $PWD/bins model_trees $PWD/RFtestingset.npy $4_RFtestingset_scores.txt

fi
