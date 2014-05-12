#!/usr/bin/python
from os import listdir, system
from os.path import isfile, join

TEST_DIR = 'tests'
files = [f for f in listdir(TEST_DIR) if isfile(join(TEST_DIR,f)) and not '.out' in f]
for file in files:
    file = '%s/%s' % (TEST_DIR, file)
    system('krun --search %s > %s.out' % (file, file))
