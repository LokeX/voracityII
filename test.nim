import os
import sequtils

let files = toSeq walkFiles "*.nim"

for f in files:
  echo f

