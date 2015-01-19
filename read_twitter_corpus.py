#!/usr/bin/env python

import csv
import sys


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: {} [twitter csv]".format(sys.argv[0]))
        return -1
    with open(sys.argv[1], 'rb') as csv_file:
        csv_reader = csv.reader(csv_file)
        for row in csv_reader:
            tweet = row[5]
            sys.stdout.write(tweet)
            if tweet[-1] != '\n':
                sys.stdout.write('\n')

if __name__ == '__main__':
    sys.exit(main())
