

#!/bin/bash

#/bin/bash

#Making working directory with Date

if [ "$1" == "-h" ]; then
  echo "Usage: `basename $0` [-h]"
  echo "RF_models.sh takes five arguments"
  echo "see example script below"
  echo "./RF_models.sh train_posset.csv train_negset.csv testset.csv RF_models_workingdir_name cdr3only[true/fasle]"
  exit 0
fi

pos="$PWD/$1"
neg="$PWD/$2"
testset= "PWD/$3"
cdr3_only=$5

if [ "$cdr3_only" = true] ; then 
        mkdir $4

#step 1
        cd $4
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

        for i in {0..9};
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
                --inputs ../$testset \
                --output_names RFtestingset \
                --use_cdr3_length False \
                --length_dependent_trimming True \
                --kmer_size 3

        mkdir models_test

        python ../RF_models/_1b_remove_chains.py loc_3mer.p RFtestingset.npy models_test/

#run prediction script using RF trees created in the earlier step. 

        python ../RF_models/_4_apply_split_RFs.py $PWD/bins model_trees $PWD/models_test/only_cd3r_obj.npy RFtestingset_scores.txt

fi

if [ "$cdr3_only" = false] ; then

       mkdir $4

#step 1
        cd $4
        date
        python ../RF_models/_1_create_kmer_dicts1.py generate loc_3mer.p \
               --inputs $pos $neg \
                --output_names pos_3mer neg_3mer \
                --length_dependent_trimming True \
                --kmer_size 3

        mkdir bins

        for i in {0..9};
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

#create python object of the testing set. 

        python ../RF_models/_1_create_kmer_dicts1.py encode loc_3mer.p \
                --inputs ../$testset \
                --output_names RFtestingset \
                --use_cdr3_length False \
                --length_dependent_trimming True \
                --kmer_size 3

#run prediction script using RF trees created in the earlier step. 

        python ../RF_models/_4_apply_split_RFs.py $PWD/bins model_trees $PWD/RFtestingset.npy RFtestingset_scores.txt

fi