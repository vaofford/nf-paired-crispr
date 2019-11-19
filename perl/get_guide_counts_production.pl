#!/usr/bin/perl
#

use strict;
use Getopt::Long;

my $usage = "Usage: get_guide_counts_production.pl --sample sample_name --library library_file --fastq1 R1_fastq --fastq2 R2_fastq\n\n \
             Generates: counts, read classification and classification stats tsv files\n";

my $nn = scalar(@ARGV);

die ( "\n$usage\n\n") if ( $nn != 8);

my($library_file, $fastq1, $fastq2, $sample_name);
GetOptions ( "library=s"    => \$library_file,
             "fastq1=s"     => \$fastq1,
     	       "fastq2=s"     => \$fastq2,
             "sample=s"     => \$sample_name )  
  or die("Error in command line arguments\n\n$usage\n");

die "Cannot find library file: $library_file\n" unless ( -e $library_file );
die "Cannot find fastq 1 file: $fastq1\n" unless ( -e $fastq1 );
die "Cannot find fastq 2 file: $fastq2\n" unless ( -e $fastq2 );

open(LIB,"< $library_file") or die (  "Error processing $library_file\n");
my $header = <LIB>;
chomp($header);
my @fields = split(/\t/, $header);

#locate the columns with the guide sequences
$_=lc for @fields; #make all fields lower case

#library file must have columns the following columns defined :
# unique_id, target_id, sgrna_left_seq_id, sgrna_left_seg, sgrna_right_seq_id, sgrna_right_seg
my $i_sgrna_left;
my $i_sgrna_left_id;
my $i_sgrna_right;
my $i_sgrna_right_id;
my $i_unique_id;
my $i_target_id;
for my $i ( 0..$#fields )
  {
  $i_sgrna_left_id = $i if ( $fields[ $i ] eq "sgrna_left_id" );
  $i_sgrna_left = $i if ( $fields[ $i ] eq "sgrna_left_seq" );
  $i_sgrna_right_id = $i if ( $fields[ $i ] eq "sgrna_right_id" );
  $i_sgrna_right = $i if ( $fields[ $i ] eq "sgrna_right_seq" );
  $i_unique_id = $i if ( $fields[ $i ] eq "unique_id" );
  $i_target_id = $i if ( $fields[ $i ] eq "target_id" );
  }
die "Missing sgrna_left_id column. Check column labels\n\n" if ( not defined $i_sgrna_left_id);
die "Missing sgrna_right_id column. Check column labels\n\n" if ( not defined $i_sgrna_right_id);

die "Missing sgrna_left_seq column. Check column labels\n\n" if ( not defined $i_sgrna_left);
die "Missing sgrna_right_seq column. Check column labels\n\n" if ( not defined $i_sgrna_right);

die "Missing unique_id column. Check column labels\n\n" if ( not defined $i_unique_id );
die "Missing target_id column. Check column labels\n\n" if ( not defined $i_target_id );

#Create various lookup dictionaries from the library file
my %lookupGuidePair;
my %lookupGuideLeft;
my %lookupGuideRight;
my %lookupGuideLeftRC; 
my %lookupGuideRightRC;
my %lookupSafe;

while( <LIB> )
  {
  chomp;
  my @line = split(/\t/);
  my $sgSeqL = $line[$i_sgrna_left];
  my $sgSeqR = $line[$i_sgrna_right];
  my $sgSeqLrc = &rc( $sgSeqL);
  my $sgSeqRrc = &rc( $sgSeqR);
  
  $lookupGuideLeft{ $sgSeqL }  = undef; #undef saves memory
  $lookupGuideRight{ $sgSeqR } = undef;
  $lookupGuideLeftRC{ $sgSeqLrc }  = undef; #undef saves memory
  $lookupGuideRightRC{ $sgSeqRrc } = undef;

  #store the safe sequences (based on the guide id)
  $lookupSafe{ $sgSeqL } = undef if ( $line[$i_sgrna_left_id]  =~ /^F\d+$/);
  $lookupSafe{ $sgSeqR } = undef if ( $line[$i_sgrna_right_id] =~ /^F\d+$/);
  
  $lookupGuidePair{ $sgSeqLrc . $sgSeqR } = 0;
  }
close(LIB);

#Read the fastq files
if ( $fastq1 =~ /\.gz$/ )
  {
  open(FQ1,"zcat $fastq1 |") or die ( "Error processing $fastq1\n");
  }
else
  {
  open(FQ1,"< $fastq1") or die ( "Error processing $fastq1\n");
  }

if ( $fastq2 =~ /\.gz$/ )
  {
  open(FQ2,"zcat $fastq2 |") or die ( "Error processing $fastq2\n");
  }
else
  {
  open(FQ2,"< $fastq2") or die ( "Error processing $fastq2\n");
  }
my $nline = 0;
my $read_id;
my ($n_safe_safe, $n_grna1_safe, $n_safe_grna2, $n_grna1_grna2)=(0,0,0,0);
my ($n_grna1, $n_grna2, $n_incorrect_pair, $n_miss_miss);
open(CLR,"> $sample_name"."_classified_reads.tsv");
while(my $r1 = <FQ1>)
  {
  my $r2 = <FQ2>;
  $nline++;
  if ( $nline % 4 == 1 )
    {
    $read_id = substr($r1,1,-3);
    }
  elsif ( $nline % 4 == 2)
    {
    chomp($r1);
    chomp($r2);
    my $pair_guide = $r2 . $r1;
    #look for correctly paired reads :
    # Reverse Complement (Read2) -> gRNA1 (left); Read1 -> gRNA2 (right)
    if ( defined $lookupGuidePair{$pair_guide} )
      {
      $lookupGuidePair{$pair_guide}++;
      my $r2rc = &rc( $r2);
      my $label1 = "gRNA1";
      my $label2 = "gRNA2";
      $label1 = "safe" if ( exists $lookupSafe{$r2rc} );
      $label2 = "safe" if ( exists $lookupSafe{$r1} );
      #count number of occurrances
      if ( $label1 eq "gRNA1" and $label2 eq "gRNA2")
        {
        $n_grna1_grna2++;
        }
      elsif ( $label1 eq "gRNA1" and $label2 eq "safe" )
        {
        $n_grna1_safe++;
        }
      elsif ( $label1 eq "safe" and $label2 eq "gRNA2" )
        {
        $n_safe_grna2++;
        }
      else
        {
        $n_safe_safe++;
        }
      print CLR "FOUND\t$label1\_$label2\t$sample_name\t$read_id\t$r1\t$r2\t$r2rc"."$r1\n";      
      }
    #both guides found but they are incorrectly paired (most reads fall here)
    elsif ( exists $lookupGuideLeftRC{ $r2 }  and exists $lookupGuideRight{ $r1 } )
      {
      $n_incorrect_pair++;
      print CLR "MISS\tgRNA1_gRNA2\t$sample_name\t$read_id\t$r1\t$r2\tNA\n";
      }
    #both guides found but they are incorrectly paired and have wrong orientation 
    elsif ( exists $lookupGuideLeft{ $r1 }  and exists $lookupGuideRightRC{ $r2 } )
      {
      $n_incorrect_pair++;      
      print CLR "MISS\tgRNA1_gRNA2\t$sample_name\t$read_id\t$r1\t$r2\tNA\n"; #few reads fall here
      }
    #only found the left guide (with either correct or wrong orientation)
    elsif (  exists $lookupGuideLeftRC{ $r2 }  or  exists $lookupGuideLeft{ $r1 } )
      {
      $n_grna1++;
      print CLR "MISS\tgRNA1_nothing\t$sample_name\t$read_id\t$r1\t$r2\tNA\n";
      }
    #only found the right guide (with either correct or wrong orientation)
    elsif (  exists $lookupGuideRight{ $r1 } or exists $lookupGuideRightRC{ $r2 } )
      {
      $n_grna2++;
      print CLR "MISS\tnothing_gRNA2\t$sample_name\t$read_id\t$r1\t$r2\tNA\n";
      }
    #didn't match any guides
    else
      {
      $n_miss_miss++;
      print CLR "MISS\tnothing_nothing\t$sample_name\t$read_id\t$r1\t$r2\tNA\n";      
      }
    }
  }
close(CLR);
my $read_counts = $nline / 4;

open(COUNTST,">$sample_name"."_classification_stats.tsv");
print COUNTST "sample\ttotal_reads\tmiss\tmismatch\tgRNA1_hits\tgRNA2_hits\tsafe_safe\tgRNA1_safe\tsafe_gRNA2\tgRNA1_gRNA2\n";
print COUNTST "$read_counts\t$n_miss_miss\t$n_incorrect_pair\t$n_grna1\t$n_grna2\t$n_safe_safe\t$n_grna1_safe\t$n_safe_grna2\t$n_grna1_grna2 \n";


open(LIB,"< $library_file") or die (  "Error processing $library_file\n");
<LIB>;

open(COUNT,">$sample_name".".counts.tsv");
print COUNT "unique_id\ttarget_id\t$sample_name\n";
while( <LIB> )
  {
  chomp;
  my @line = split(/\t/);
  my $sgSeqL = $line[$i_sgrna_left];
  my $sgSeqR = $line[$i_sgrna_right];
  my $unique_pair_id = $line[$i_unique_id];
  my $target_pair_id = $line[$i_target_id];
  my $sgSeqLrc = &rc( $sgSeqL);
  my $counts = $lookupGuidePair{ $sgSeqLrc . $sgSeqR };
  print COUNT "$unique_pair_id\t$target_pair_id\t$counts\n";
  }
close(LIB);
close(COUNT);

#reverse complement function
sub rc
  {
  my $seq = reverse $_[0];
  $seq =~ tr/ATGC/TACG/;
  return $seq;
  }
