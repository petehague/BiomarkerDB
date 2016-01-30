package BMARFF;
use strict;
use warnings;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_arff);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_arff($) {
# Subroutine to convert the finalised data into ARFF format
# # Peter Hague 2008-Aug-27
  my ($filename)=@_;
  my (@cols, @centroid, @peaks, @output, @metadata, $fluxfile, $targetfile, $metadata, $curpeak, $index);

  $fluxfile=$filename;
  $fluxfile=~s/aggregate-pk/flux/;
  $targetfile=$filename;
  $targetfile=~s/aggregate-pk.csv/final.arff/;
  $metadata=$targetfile;
  $metadata=~s/final.arff/igroup.mdt/;

# Retrieve centroids from aggregate-pk
  open (SOURCE, $filename);
  while (<SOURCE>) {
    @cols=split /\,/,$_;
    if ($cols[1] ne "centroid") {
      $peaks[$curpeak]=$cols[0];
      $centroid[$curpeak]=$cols[1];
      $curpeak++;
    }
  }
  close SOURCE;

# Retrieve and format flux data
  open (SOURCE, $fluxfile);
  $curpeak=0;
  while (<SOURCE>) {
    @cols=split /\,/,$_;
    if ($peaks[$curpeak] eq @cols[0]) {
      for ($index=1;$index<@cols;$index++) {
	if ($curpeak eq 0) {
	  $output[$index-1]=@cols[$index];
	} else {
	  $output[$index-1].=",".@cols[$index];
	}
      }
      $curpeak++;
    }
  }
  close SOURCE;

# Read metadata
  open (SOURCE, $metadata);
  while (<SOURCE>) {
    @cols=split /\,/,$_;
    for ($index=0;$index<@cols;$index++) {
      push (@metadata, $cols[$index]);
    }
  }
  close SOURCE;
  for ($index=0;$index<@output;$index++) {
    $output[$index].=",".$metadata[$index];
  }

# Write to target file
  open (TARGET, ">$targetfile");
  print TARGET "\@RELATION mass-spec\n\n";
  for ($index=0;$index<@centroid;$index++) {
    print TARGET "\@ATTRIBUTE   ".$centroid[$index]." real\n";
  }
  print TARGET "\@ATTRIBUTE   igroup numeric\n\n";
  print TARGET "\@DATA\n";
  for ($index=0;$index<@output;$index++) {
    print TARGET $output[$index]."\n";
  }
  close TARGET;
}

END { }
1;
