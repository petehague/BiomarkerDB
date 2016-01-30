package BMGAUSS;
use strict;
use warnings;

use BMCONF;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_gaussian &bm_sigma_file &bm_generate_curve);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_gaussian($) {
# Function to perform gaussian smoothing on spectrum and variance
# # Peter Hague 2008-Jun-30
  my ($filename)=@_;
  my ($path, $shortname, $start, $end, $width, $index, $sigma, $sum, $subindex);
  my (@cols, @rawdata, @flux, @rawvariance, @gaussian, @peaks, @variance,@sigs);
  
# Retrieving settings for this dataset
  $filename=~/(.+)\/(.+)/;
  $path=$1;
  $shortname=$2;
  $start=&bm_db_getconf($path,"BinStart")+(&bm_db_getconf($path,"BinSize")/2);
  $end=&bm_db_getconf($path,"BinEnd")+(&bm_db_getconf($path,"BinSize")/2);

# Extract data from processed .csv file
  open(SOURCE,$filename);
  while (<SOURCE>) {
    chomp;
    @cols=split /\,/,$_;
    if ($cols[0]=~/^[0-9]/) {
      $flux[$cols[0]]=$cols[1];
      $rawdata[$cols[0]]=$cols[3];
      $rawvariance[$cols[0]]=$cols[4];
    }
  }
  close SOURCE;

# Retrieve sigma values. 4.72 is an abitary value determined by data
  @sigs=&bm_sigma_file($filename, $start, $end, 4.72);

# Outputs sigma value table for diagnostic purposes
  #open (SIGMA,">".$filename.".sig");
  #for ($index=$start;$index<=$end;$index++) {
  #  print SIGMA $index.",".@sigs[$index]."\n";
  #}
  #close SIGMA;

# Loop through all bins applying guassian function
  for ($index=$start;$index<=$end;$index++) {
    $sigma=@sigs[$index];
    if ($sigma==0) { die "Invalid Sigma"; }
    @gaussian=&bm_generate_curve($index, $sigma);
    $width=abs(@gaussian/2);

# Multiply guassian values in window with corresponding bins, then sum
    $sum=0;
    for ($subindex=$index-$width;$subindex<=$index+$width;$subindex++) {
      if ($subindex>=$start && $subindex<=$end) {
	$sum+=$gaussian[$subindex-$index+$width-1]*$rawdata[$subindex];
      }
    }
    $peaks[$index]=$sum;

# Repeat process for variances
    $sum=0;
    for ($subindex=$index-$width;$subindex<=$index+$width;$subindex++) {
      if ($subindex>=$start && $subindex<=$end) {
	$sum+=$gaussian[$subindex-$index+$width-1]*$rawvariance[$subindex];
      }
    }
    $variance[$index]=$sum;

# Repeat for unsubstracted fluxes
    $sum=0;
    for ($subindex=$index-$width;$subindex<=$index+$width;$subindex++) {
      if ($subindex>=$start && $subindex<=$end) {
	$sum+=$gaussian[$subindex-$index+$width-1]*$flux[$subindex];
      }
    }
    $flux[$index]=$sum;
  }

# Write data to file
  $filename=~s/\.csv/-gs\.csv/;
  open(TARGET,">$filename");
  print TARGET "bin,peaks,variance,flux\n";
  for ($index=$start;$index<=$end;$index++) {
    print TARGET $index.",".$peaks[$index].",".$variance[$index].",".$flux[$index]."\n";
  }
  close TARGET;
}

sub bm_sigma_file($$$$) {
# Function to load in sigma values
# # Peter Hague 2008-Jul-14
  my ($filename, $start, $end,$divvalue)=@_;
  my (@cols, @sigma,$confsigma,$index, $path, $file);

# If the value in the conf file is nonzero, use it for all mz values
  $filename=~/(.+)\/(.+)/;
  $path=$1;
  $file=$2;
  $confsigma=&bm_db_getconf($path, "Sigma");

  if ($confsigma eq "0" || $file=~/aggregate/) {
    for ($index=$start;$index<=$end;$index++) {
      $sigma[$index]=(1.71066+(0.0005874*$index))/$divvalue;
    }
  } else {
    for ($index=$start;$index<=$end;$index++) {
      $sigma[$index]=$confsigma;
    }
  }

  return @sigma;

# No longer used
# Looks for sigma.conf in the same directory as the data file
  if ($confsigma eq "0" || $file=~/aggregate/) {
    open(SIGMAFILE,$path."/sigma.conf") or die "666 Infernal Server Error";
    while (<SIGMAFILE>) {
      chomp;
      $_=~s/\s//g;
      @cols=split /\,/,$_;
      if ($cols[0]=~/^[0-9]/) { 
	$sigma[$cols[0]]=$cols[1]/$divvalue; 
      }
    }
    close SIGMAFILE;
  } else {
    for ($index=$start;$index<=$end;$index++) {
      $sigma[$index]=$confsigma;
    }
  }

  return @sigma;
}

sub bm_generate_curve($$) {
# Function to generate a gaussian curve specific to m/z value
# # Peter Hague 2008-Jun-30
  my ($mz, $sigma)=@_;
  my ($index, $sum, $numbins,$constant, @gaussian, @full);

# Create half a standard guassian curve
  $numbins=0;
  while ($numbins==0 || $gaussian[$numbins-1]>=0.001) {
    $gaussian[$numbins]=exp(-($numbins*$numbins)/(2*($sigma*$sigma)));
    $numbins++;
  }

# Double it up
  @full=@gaussian;
  @gaussian=reverse(@gaussian);
  pop(@gaussian);
  @full=(@gaussian, @full);

# Calibrate it such that the integral of it is 1
  $sum=0;
  for $index(@full) {
    $sum+=$index;
  }
  $constant=1/$sum;
  for ($index=0;$index<@full;$index++) {
    $full[$index]*=$constant;
  }

  return @full;
}

END { }
1;
