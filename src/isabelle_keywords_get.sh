#!/bin/sh

# Copyright (C) 2012  INRIA and Microsoft Corporation

# This script generates the "isabelle_keywords.ml" file.
# It assumes a working installation of Isabelle is in the PATH.

eval `isabelle getenv ISABELLE_HOME`

{
  echo '(* AUTOMATICALLY GENERATED by isabelle_keywords_get.sh - DO NOT EDIT *)'
  echo 'Revision.f "$Rev: 29196 $";;'
  echo 'let v = ['

  sed -n -e '/^.*"\([^"]*\)".*$/s//\1/p' $ISABELLE_HOME/etc/isar-keywords*.el \
  | sed -e 's/\\\\\././g' \
  | sort -u \
  | sed -e 's/.*/  "&";/'

  echo '];;'
} > isabelle_keywords.ml
