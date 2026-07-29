#!/bin/bash
set -e

cobc -x src/PAYMENTPROC.cob -o PAYMENTPROC
./PAYMENTPROC
