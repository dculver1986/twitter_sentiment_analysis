#!/usr/bin/env perl
use strict;
use warnings;

use Net::Twitter;

use Lingua::EN::Tagger;
use Lingua::EN::Splitter qw(words);
use Lingua::EN::StopWords qw(%StopWords);
use Text::Trim;
use Text::CSV;
use Data::Dumper;
use DateTime;

# Auth to twitter
my $nt = Net::Twitter->new(
      traits              => [ qw/AppAuth API::RESTv1_1/ ],
      consumer_key        => 'INSERT CONSUMER KEY',
      consumer_secret     => 'INSERT CONSUMER SECRET',
      access_token        => 'INSERT ACCESS TOKEN',
      access_token_secret => 'INSERT TOKEN SECRET',
);

print "Authenticating to twitter..\n";
$nt->request_access_token;
#print 'token: ', $nt->access_token,"\n";

# search tweets
sub search {
    my $text = shift;
    my $max_count = shift;
    my $r = $nt->search({ q => $text, count => $max_count });
    return $r;
}

my $r = search( $ARGV[0], $ARGV[1] );

# build corpus
my $corpus;
for my $status ( @{$r->{statuses}} ) {
        $corpus .= "$status->{text} ";
        #print "$status->{text}\n";
}

my $words = words($corpus);
my @new_words;
# remove stop words, create new word list/array
for my $word (@$words) {
    # Stop Words usually refer to the most common words in a language.
    trim($word);
    $word =~ s/^http[s]?.*//g;
    $word =~ s/^rt$//gi; #remove retweet tag
    $word =~ s/\W//g; # remove non word chars
    $word =~ s/^\w?$//g; # remove one letter words
    $word =~ s/^co$//g; # remove co
    $word =~ s/^amp$//g;
    if ( !( grep { $StopWords{$_} } $word )
        || length(trim($word)) > 1 ) {
        push @new_words, $word;
    }
}

#print Dumper(\@new_words);
my $posfile = 'positivewords.txt';
my $negfile = 'negative-words.txt';
# build positive and negative words list
open ( my $posfh, '<', $posfile) or die;
open ( my $negfh, '<', $negfile) or die;

my ( @poswords, @negwords );
push @poswords , trim($_) for <$posfh>;
push @negwords, trim($_) for <$negfh>;

my @found_pos_words;
my @found_neg_words;
# find positive / negative words

print "counting instances of positive & negative words..\n";

my $vote_tags = 0;
my %wordhash;
my $sum = 0;
for my $i ( @new_words ) {
    if ( $i ne '' ) {
        if ( $i eq 'vote' ) { $vote_tags++; }
        if ( (grep { $_ eq $i } @poswords) ) {
            push @found_pos_words, $i;
        }
        elsif ( (grep { $_ eq $i } @negwords ) ) {
            push @found_neg_words, $i;
        }
    }
}

my %f;
for my $found (@found_pos_words) {
    if ( (grep { $_ eq $found } @poswords ) ) {
        $f{$found}++;
    }
}
# create hash of positive and negative words with word and frequencies
my %g;
for my $found (@found_neg_words) {
    if ( (grep { $_ eq $found } @negwords ) ) {
        $g{$found}++;
    }
}

my $file = "sa_results_$ARGV[0]_".DateTime->today->ymd.".csv";
open ( my $out, '>', $file) or die;
# create csv, print positive word, frequency of word
for my $poskey ( sort keys %f ) {
    print $out $poskey.','.$f{$poskey},"\n";
}
# print negative word, frequency of word
for my $negkey ( sort keys %g ) {
    print $out $negkey.','.$g{$negkey},"\n";
}

# close file
close $out;

# display numerical results
print "Found ". scalar(@found_pos_words). " total positive words\n";
print "Found ". scalar(@found_neg_words). " total negative words\n";
#print "Found ". $vote_tags . " vote tags\n";
