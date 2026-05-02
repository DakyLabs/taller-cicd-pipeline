#!/bin/bash

for file in calculator calculator-scientific;
do
    mv results/TESTS-features.${file}.xml results/behavior_${file}_results.xml
    junit2html results/behavior_${file}_results.xml results/behavior_${file}_results.html
done
