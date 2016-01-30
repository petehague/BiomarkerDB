package BMPEAKS;
use strict;
use warnings;

use BMCONF;
use BMSTATUS;
use BMGAUSS;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_combine &bm_db_peaks &bm_db_normpks);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_combine($) {
# Function to combine all data files in a given directory into a single .csv file
# # Peter Hague 2008-Jul-16
  my ($pathname)=@_;
  my ($filename, $outputfile, $numfiles, $index); 
  my (@files, @bins, @backs, @subs, @vars, @cols);
  my $start=&bm_db_getconf($pathname,"BinStart")+&bm_db_getconf($pathname,"BinSize")/2;
  my $end=&bm_db_getconf($pathname,"BinEnd")+&bm_db_getconf($pathname,"BinSize")/2;

# Read in smoothed bins from all files
  $outputfile=$pathname."/aggregate.csv";
  @files=glob "$pathname/*.csv";
  foreach $filename (@files) {
    if (!($filename=~/-gs.csv/) && !($filename=~/-fl.csv/)) {
      $numfiles++;
      open(SOURCE,$filename);
      while (<SOURCE>) {
	chomp;
	@cols=split /\,/,$_;
	$bins[$cols[0]]+=$cols[1];
	$backs[$cols[0]]+=$cols[2];
	$subs[$cols[0]]+=$cols[3];
	$vars[$cols[0]]+=$cols[4];
      }
      close SOURCE;
    }
  }

# Write to aggregate file
  open(TARGET,">$outputfile");
  print TARGET "bin,value,background,subtracted,variance\n";
  for ($index=$start;$index<=$end;$index++) {
    print TARGET $index.",".($bins[$index]/$numfiles).",".($backs[$index]/$numfiles).",".($subs[$index]/$numfiles).",".($vars[$index]/($numfiles**2))."\n";
  }
  close TARGET;
}

sub bm_db_peaks($) {
# Function to identified peaks on smoothed data and plot significance
# # Peter Hague 2008-Jun-30
  my ($filename)=@_;
  my ($pathname, $shortname, $start, $end, $index, $threshold, $curpeak, $line);
  my (@cols, @data, @variance, @rawdata, @significance, @peaks, @sigmas, @sigpeaks);

  $filename=~/(.+)\/(.+)/;
  $pathname=$1;

  $start=&bm_db_getconf($pathname,"BinStart")+(&bm_db_getconf($pathname,"BinSize")/2);
  $end=&bm_db_getconf($pathname,"BinEnd")+(&bm_db_getconf($pathname,"BinSize")/2);
  @sigmas=&bm_sigma_file($filename, $start, $end, 2);

# Read in data
  open (SOURCE,$filename);
  while (<SOURCE>) {
    chomp;
    @cols=split /\,/,$_;
    if ($cols[0]=~/^[0-9]/) {
      $data[$cols[0]]=$cols[1];
      $variance[$cols[0]]=$cols[2];
    }
  }
  close SOURCE;

# Read in unsmoothed data
  $filename=~s/-gs.csv/.csv/;
  open (SOURCE,$filename);
  while (<SOURCE>) {
    chomp;
    @cols=split /\,/,$_;
    if ($cols[0]=~/^[0-9]/) {
      $rawdata[$cols[0]]=$cols[3];
    }
  }
  close SOURCE;

# Determine local maxima
  @peaks=();
  for ($index=$start;$index<=$end;$index++) {
    if ($data[$index]>$data[$index-1] && $data[$index]>$data[$index+1]) {
      push(@peaks,$index);
    }
  }

# Determine significance
  foreach $index(@peaks) {
    if ($variance[$index]>0) {
      @significance[$index]=$data[$index]/(sqrt($variance[$index]));
    }
  }
  
# Pick out significant peaks
  foreach $index(@peaks) {
    if ($significance[$index]>$threshold && $data[$index]>100) { 
	push(@sigpeaks, $index);
    }
  }

  $filename=~s/.csv/-pk\.csv/;
  open (TARGET, ">$filename");
  print TARGET "peak,centroid,flux\n";
  foreach $index(@sigpeaks) {
    print TARGET $index.",".&bm_db_centroid(\@rawdata, $index, $sigmas[$index]).",".&bm_db_integrate(\@rawdata, $index, $sigmas[$index])."\n";
  }
  close TARGET;

}

sub bm_db_normpks($) {
# Subroutine to normalise the peaks of all samples
# # Peter Hague 2008-Aug-13
  my ($filename)=@_;
  my ($pathname, $start, $end, @cols, @peaks, @files, @data, @var, @filedata, @filevar, @normdata, @normpeaks, @mean, @scatter, @sigmas,@output, $datafile, $curfile, $curpeak, $index, $subindex, $total, $sqtotal, $samples, $action);

  $filename=~/(.+)\/(.+)/;
  $pathname=$1;

  $start=&bm_db_getconf($pathname,"BinStart")+(&bm_db_getconf($pathname,"BinSize")/2);
  $end=&bm_db_getconf($pathname,"BinEnd")+(&bm_db_getconf($pathname,"BinSize")/2);
  @sigmas=&bm_sigma_file($filename, $start, $end, 2);

# Extract peak positions as integer m/z values
  open (SOURCE,$filename);
  $curpeak=0;
  while (<SOURCE>) {
    chomp;
    @cols=split /\,/,$_;
    if ($cols[0]=~/^[0-9]/) {
      $peaks[$curpeak]=$cols[0];
      $curpeak++;
    }
  }
  close SOURCE;

# Read unsmoothed flux data for all samples and integrate peaks
  @files=glob "$pathname/*.csv";
  $curfile=0;
  foreach $datafile (@files) {
    if ($datafile=~/.csv/ && !($datafile=~/aggregate/) && !($datafile=~/-gs.csv/) && !($datafile=~/-fl.csv/)) {
      $curpeak=0;
      $datafile=~/(.+)\/(.+)/;
      $samples.=",".$2;
      $samples=~s/.csv//;
      open(SOURCE,$datafile);
      while (<SOURCE>) {
	chomp;
	@cols=split /\,/,$_;
	$data[$cols[0]]=$cols[3];
      }
      close SOURCE;
      for ($index=0;$index<@data;$index++) {
	if ($index eq $peaks[$curpeak]) {
	  $filedata[$curfile].=",".&bm_db_integrate(\@data, $index, $sigmas[$index]);
	  $normdata[$curpeak].=",".&bm_db_integrate(\@data, $index, $sigmas[$index]);
	  $curpeak++;
	}
      }
      $curfile++;
    }
  }

# Read unsmoothed variance data for all samples and integrate peaks
  @files=glob "$pathname/*.csv";
  $curfile=0;
  foreach $datafile (@files) {
    if ($datafile=~/.csv/ && !($datafile=~/aggregate/) && !($datafile=~/-gs.csv/) && !($datafile=~/-fl.csv/)) {
      $curpeak=0;
      $datafile=~/(.+)\/(.+)/;
      open(SOURCE,$datafile);
      while (<SOURCE>) {
	chomp;
	@cols=split /\,/,$_;
	$var[$cols[0]]=$cols[4];
      }
      close SOURCE;
      for ($index=0;$index<@var;$index++) {
	if ($index eq $peaks[$curpeak]) {
	  $filevar[$curfile].=",".&bm_db_integrate(\@var, $index, $sigmas[$index]);
	  $curpeak++;
	}
      }
      $curfile++;
    }
  }

  for (my $i=0;$i<4;$i++) {
# Call normalisation subroutine
    if ($i eq 0) { $action=1; } else { $action=0; }
    $normpeaks[$i]=&bm_db_donorm(\@normdata, \@filedata, \@filevar, \@peaks, $action, $pathname);

# Write data to flux file
    @output=();
    for ($index=0;$index<@filedata;$index++) {
      @cols=split /\,/,$filedata[$index];
      for ($subindex=1;$subindex<@cols;$subindex++) {
	$output[$subindex-1].=",".$cols[$subindex];
      }
    }
    open (TARGET,">$pathname/flux$i.csv");
    print TARGET "peak".$samples."\n";
    for ($index=0;$index<@peaks;$index++) {
      print TARGET $peaks[$index].$output[$index]."\n";
    }
    close TARGET;
    
# Write data to scatter file
    @output=();
    for ($index=0;$index<@filevar;$index++) {
      @cols=split /\,/,$filevar[$index];
      for ($subindex=1;$subindex<@cols;$subindex++) {
	$output[$subindex-1].=",".$cols[$subindex];
      }
    }
    open (TARGET,">$pathname/scatter$i.csv");
    print TARGET "peak".$samples."\n";
    for ($index=0;$index<@peaks;$index++) {
      print TARGET $peaks[$index].$output[$index]."\n";
    }
    close TARGET;
  }

# Write data to flux file
  @output=();
  for ($index=0;$index<@filedata;$index++) {
    @cols=split /\,/,$filedata[$index];
    for ($subindex=1;$subindex<@cols;$subindex++) {
      $output[$subindex-1].=",".$cols[$subindex];
    }
  }
  open (TARGET,">$pathname/flux.csv");
  print TARGET "peak".$samples."\n";
  for ($index=0;$index<@peaks;$index++) {
    print TARGET $peaks[$index].$output[$index]."\n";
  }
  close TARGET;
  
# Write data to scatter file
  @output=();
  for ($index=0;$index<@filevar;$index++) {
    @cols=split /\,/,$filevar[$index];
    for ($subindex=1;$subindex<@cols;$subindex++) {
      $output[$subindex-1].=",".$cols[$subindex];
    }
  }
  open (TARGET,">$pathname/scatter.csv");
  print TARGET "peak".$samples."\n";
  for ($index=0;$index<@peaks;$index++) {
    print TARGET $peaks[$index].$output[$index]."\n";
  }
  close TARGET;
  
# Write peak data
  @output=();
  for ($index=0;$index<@normpeaks;$index++) {
    @cols=split /\,/,$normpeaks[$index];
    $output[0]=$cols[1];
    for ($subindex=2;$subindex<@cols;$subindex++) {
      $output[$subindex-1].=",".$cols[$subindex];
    }
  }
  open (TARGET,">$pathname/normpeaks.csv");
  print TARGET "first,second,third,fourth\n";
  for ($index=0;$index<@output;$index++) {
    print TARGET $output[$index]."\n";
  }
  close TARGET;
}

sub bm_db_donorm($$$$$$) {
# Subroutine to apply normalisation
# # Peter Hague 2008-Aug-20
  my ($refnormdata, $reffiledata, $reffilevar, $refpeaks, $action, $pathname)=@_;
  my (@cols, @colsvar, @normdata, @filedata, @filevar, @peaks, @normpeaks, @mean, @scatter, $index, $subindex, $total, $sqtotal, $curpeak, $output, $cmin, $cmax, $smax);

  @normdata=@{$refnormdata};
  @filedata=@{$reffiledata};
  @filevar=@{$reffilevar};
  @peaks=@{$refpeaks};

  $cmin=&bm_db_getconf($pathname,"MinFlux");
  $cmax=&bm_db_getconf($pathname,"MaxFlux");
  $smax=&bm_db_getconf($pathname,"MaxScatter");

# Find normalisation peaks. If this is the first run, get them from file
  if ($action eq 1 ) {
    open (SOURCE,"$pathname/aggregate-pk.csv");
    while (<SOURCE>) {
      @cols=split /\,/,$_;
      if ($cols[2]>$cmin && $cols[2]<$cmax) {
	push (@normpeaks,$cols[0]);
	for ($index=0;$index<@peaks;$index++) {
	  if ($peaks[$index] eq $cols[0]) { $mean[$index]=$cols[2]; }
	}
      }
    }
    close SOURCE;
  } else {
    for ($index=0;$index<@normdata;$index++) {
      @cols=split /\,/,$normdata[$index];
      $total=0;
      $sqtotal=0;
      for ($subindex=1;$subindex<@cols;$subindex++) {
	$total+=$cols[$subindex];
	$sqtotal+=($cols[$subindex]*$cols[$subindex]);
      }
      $mean[$index]=$total/(@cols-1);
      $scatter[$index]=sqrt((($sqtotal/(@cols-1))/($mean[$index]*$mean[$index]))-1);
      
      if ($mean[$index]>$cmin && $mean[$index]<$cmax && $scatter[$index]<$smax) {
	if ($peaks[$index]) { push (@normpeaks,$peaks[$index]); }
      }
    }
  }

# Apply normalisation to samples 
  if (@normpeaks>0) {
    for ($index=0;$index<@filedata;$index++) {
      @cols=split /\,/,$filedata[$index];
      
      $curpeak=0;
      $total=0;
      $sqtotal=0;
      for ($subindex=1;$subindex<@cols;$subindex++) {
	if ($peaks[$subindex-1] eq $normpeaks[$curpeak]) { 
	  $total+=$cols[$subindex]/$mean[$subindex-1]; 
	  $sqtotal+=($cols[$subindex]*$cols[$subindex])/($mean[$subindex-1]*$mean[$subindex-1]);
	  $curpeak++;
	}
      }
      $total=$total/$sqtotal;
      $sqtotal=$total*$total;
      
      $filedata[$index]="";
      for ($subindex=1;$subindex<@cols;$subindex++) {
	$filedata[$index].=",".$cols[$subindex]*$total;
      }
      
      @colsvar=split /\,/,$filevar[$index];
      $filevar[$index]="";
      for ($subindex=1;$subindex<@colsvar;$subindex++) {
	$filevar[$index].=",".$colsvar[$subindex]*$sqtotal;
      } 
    }
  }

#Populate normdata from filedata
  @normdata=();
  for ($index=0;$index<@filedata;$index++) {
    @cols=split /\,/,$filedata[$index];
    for ($subindex=1;$subindex<@cols;$subindex++) {
      $normdata[$subindex-1].=",".$cols[$subindex];
    }
  }

  @{$refnormdata}=@normdata;
  @{$reffiledata}=@filedata;
  @{$reffilevar}=@filevar;

  for ($index=0;$index<@normpeaks;$index++) {
    $output.=",".$normpeaks[$index];
  }

  return $output;
}

sub bm_db_integrate($$$) {
# Subroutine to find the area underneath a specific peak
# # Peter Hague 2008-Aug-12
  my ($refdata, $bin, $sigma)=@_;
  my ($sum,$index);

  $sigma=&nint($sigma);

  $sum=0;
  for ($index=$bin-$sigma;$index<=$bin+$sigma;$index++) {
    $sum+=${$refdata}[$index];
  }

  return $sum;
}

sub bm_db_centroid($$$) {
# Subroutine to fine the centroid of a peak
# # Peter Hague 2008-Aug-12
  my ($refdata, $bin, $sigma)=@_;
  my ($sum,$weights,$index);

  $sigma=&nint($sigma);

  $sum=0;
  $weights=0;
  for ($index=$bin-$sigma;$index<=$bin+$sigma;$index++) {
    $sum+=${$refdata}[$index];
    $weights+=${$refdata}[$index]*$index;
  }

  if ($sum eq 0) { $sum=0.01; }

  return $weights/$sum;
}

sub nint($) {
  my ($decimal)=@_;
  my ($integer);

  $integer=int($decimal);
  if (abs($decimal-$integer)>=0.5) {
    $integer+=($integer/abs($integer));
  }

  return $integer;
}

END { }
1;
