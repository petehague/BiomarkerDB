package BMSORT;
use strict;
use warnings;

use BMSTATUS;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_sortall);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_sortall ($$$$) {
# bm_db sorting script
# Derived from sort_all.pl script
# # Peter Hague 2008-Jun-17

  my ($path,$mzmin,$mzmax,$mzbin)=@_;
  my ($nroot,$root,$nfile,$header,$pfile);

# set spectrum sort parameters and write to file
  $pfile="$path/sort_parameters.dat";
  open DAT, ">$pfile" or die "cannot create $pfile\n";
  print DAT "mzmin(r7.2) mzmax(r7.2) mzbin(r7.4) \" \" \n";
  print DAT "$mzmin $mzmax $mzbin\n";
  close DAT;

# create list of root file names on sort_root.dat
  &bm_db_sortroot($path);

# work through root file names and create binned spectra
  @ARGV="$path/sort_root.dat";
  $header=<>;
  $nroot=0;
  while(<>) {
    chomp;
    ($nfile,$root)=split / /;
    &bm_db_binspec($path, $root, $mzmin, $mzmax, $mzbin);
    $nroot++;
  }
}

sub bm_db_sortroot ($) {
# bm_db filename root sorting script
# Derived from sort_root.pl script
# # Peter Hague 2008-Jun-17

  my ($path)=@_;
  my ($file,@files,%fnames,$key,$nfile);

# get all txt data file names
  $file="$path/*.txt";
  @files=glob $file;
  if(!@files) {
    die "no $file data files found\n";
  }
# sort files into numerical order according to individual number
  foreach $file (@files) {
    if($file=~/\/(.+)[abcd]\.txt/) {
      $key="$1";
      $fnames{$key}++;
    } 
  }

# create data file
  open DAT, ">$path/sort_root.dat" or die "cannot create file sort_root.dat\n";
  print DAT "nroot(i3) fname(c30) \" \"\n";

# write sorted file names to file
  $nfile=0;
  foreach  $key (sort keys %fnames) {
    print DAT "$fnames{$key} $key\n";
    $nfile++;
  }	
  close DAT;
}

sub bm_db_binspec($$$$$) {
# bm_db spectrum binning script
# Derived from binspec.pl script
# # Peter Hague 2008-Jun-17

  my ($path, $infiles, $mzmin, $mzmax, $mzbin)=@_;
  my ($nb,$file,@cols,$mz,$val,$in,@spectrum);
  my (@files);

# find total number of bins
  $nb=($mzmax-$mzmin)/$mzbin;

# initialize all bins
  for(1..$nb) {
    push(@spectrum,0);
  }

# get files
  chdir($path);
  $infiles=~s/.+\///;
  @files=glob "$infiles*.txt";

# Loop for all lines in input files
  foreach $file (@files) {
    open (INPUT,$file) or die "666 Infernal Server Error"; 
    &bm_db_status($path,"Sorting $file",25);
    while (<INPUT>) {
      chomp;
      @cols=split /\s+/,$_;
      $mz=shift(@cols);
      $val=shift(@cols);
      $in=($mz-$mzmin)/$mzbin;
      if($in>0&&$in<$nb) {
	$spectrum[$in]=$spectrum[$in]+$val;
      }
    }
    &bm_db_status($path,"Sorting $file",75);
    close INPUT;
  }

# create .dat file
  &bm_db_status($path,"Creating $infiles.dat",0);
  open DAT, ">$path/$infiles.dat" or die "cannot create file $infiles.dat\n";
  print DAT "mz(r7.1) cts(r8.1)\n";
  &bm_db_status($path,"Creating $infiles.dat",25);
  $mz=$mzmin+$mzbin/2;
  foreach  $val (@spectrum) {
    printf DAT "%7.1f %8.1f\n",$mz,$val;
    $mz=$mz+$mzbin;
  }	
  close DAT;
}

END { }
1;
