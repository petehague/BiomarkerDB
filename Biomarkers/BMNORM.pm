package BMNORM;
use strict;
use warnings;

use BMSTATUS;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_normalise);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_normalise($) {
# Subroutine to normalise filenames in target directory
# # Peter Hague 2008-Jun-17

  my ($path)=@_;

  my (@dirlist,$file,$startname,$variant,$name);
  my (%components, $samplekey,$index,$pattern);
  my @shotlist=("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z");

# Retrieve and sort directory list
  opendir(LOCAL, "$path/") or die "Can't open local directory";
  @dirlist=(@dirlist, readdir(LOCAL));
  closedir(LOCAL);
  @dirlist=sort @dirlist;

# Create a temporary directory to avoid overwrite problems
  mkdir ($path."/temp");

# Cycle through files and break them down into variants
  $index=0;
  $pattern="";
  &bm_db_status($path,"Normalising filenames",33);
  foreach $file (@dirlist) {
    if ($file=~/(.+)\.txt/) {
      $file=$1;
      $startname=$file;
      $name="";
      
# Strip off sequences of the same type of characters
      while ($file) {
	$file=~s/^[^a-zA-Z0-9]+//;
	$file=~s/[^a-zA-Z0-9]+$//;
	if ($file=~/([a-z]+)$/) { $variant=$1; }
	elsif ($file=~/([A-Z]+)$/) { $variant=$1; }
	elsif ($file=~/([0-9]+)$/) { $variant=$1; }
	$file=~s/$variant$//;
	$name="$name $variant";
      }
      
# Remove leading space and group together sample id
      $name=~s/^\s//g;
      while ($name=~/(.+)\s(.+)\s(.+)\s(.+)\s(.+)/) { $name="$1 $3$2 $4 $5"; }
      
# For filenames lacking a shot number, add one
      if ($name=~/^[a-zA-Z0-9]+\s[a-zA-Z0-9]+\s[a-zA-Z0-9]+$/) { $name="0 $name"; }

      $components{$startname}=$name;

# Compare components to previous loop, update shot id accordingly
      if ($name=~/^[a-zA-Z0-9]+\s$pattern$/) {
	$index++;
      } else {
	$index=0;
	$pattern=$components{$startname};
	$pattern=~s/^[a-zA-Z0-9]+\s//;
      }
      $components{$startname}=~s/^[a-zA-Z0-9]+\s//;
      $components{$startname}="$shotlist[$index] $components{$startname}";
      
# Restore components to a filename
      $components{$startname}=~s/(.+)\s(.+)\s(.+)\s(.+)/$4\-$3\-$2$1/;

# Move the file
      system("mv -f ".$path."/".$startname.".txt ".$path."/temp/".$components{$startname}.".txt");
    }
  }

# Remove source files and replace them with temporary files
  system("rm -f ".$path."/*.txt"); 
  system("mv -f ".$path."/temp/*.txt ".$path."/");
  rmdir($path."/temp");
}

END { }
1;
