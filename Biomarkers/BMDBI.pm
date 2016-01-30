package BMDBI;
use strict;
use warnings;
use DBI;
use CGI qw(:standard escapeHTML escape);
use CGI::Carp qw ( fatalsToBrowser );
use File::Basename;
use Cwd;

use BMINIT;
use BMSORT;
use BMNORM;
use BMCONF;
use BMBACKSUB;
use BMGAUSS;
use BMPEAKS;
use BMFLUX;
use BMARFF;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_web);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_web() {
# bm_db_web pages
# # Dick Willingale 2008-Jun-10
# # Ammended Peter Hague 2008-Jun-16
        $CGI::POST_MAX = 1024 * 1024 * 1000; # 1000 meg file size limit

	my $tmp=&bm_db_init(); #routine needs fixing
	my $submit=param("function");
	if(!defined($submit)) {
# Prompt for username and password
		&bm_db_webprompt();
	} elsif ($submit eq "login") {
# Login to database
		my $user=param("username");
		my $pass=param("password");
		&bm_db_weblogin($submit,$user,$pass,"$tmp/users/$user");
	} elsif  (!defined(cookie("username")) && !defined(param("username"))) { 
	        die "Session expired" 
	} elsif ($submit eq "continue" || $submit eq "cancel") {
	        &bm_db_webhome();       
	} elsif ($submit eq "upload") {
	        &bm_db_webupload(0);
	} elsif ($submit eq "list") {
	        &bm_db_weblist();
	} elsif ($submit eq "examine") {
	        &bm_db_weblook(param("id"));
	} elsif ($submit eq "delete") {
	        &bm_db_webkill(param("id"));
	} elsif ($submit eq "status") {
	        &bm_db_webstatus(param("id"));
	} elsif ($submit eq "settings") {
	        my $project="<default>";
		if (param("project")) { $project=param("project"); }
	        &bm_db_websettings($project);
	} elsif ($submit eq "apply") {
	        &bm_db_websave();
	}
}

sub bm_db_weblogin($$$$) {
# Home page of Biomarkers Database
# Arguments:	$submit	action
#  		$user	username
# 		$pass	password
# 		$tml	temporary directory
# # Dick Willingale 2008-Jun-10
# # Ammended Peter Hague 2008-Jun-16
	my ($submit,$user,$pass,$tmp)=@_;

	my %passwords=("rw", "hotdog", "ph", "burger", "dj", "pizza", "ft", "chips");

	if($passwords{$user} eq $pass) {
# Introducing cookies to enable user to stay logged in through multiple pages
# This is horribly insecure, must add crypt() function at a later date
                my $session_name=cookie(-name=>"username",-value=>$user,-expires=>"+24h");
		my $session_id=cookie(-name=>"id",-value=>$pass,-expires=>"+24h");
		print header(-cookie=>[$session_name,$session_id]);
		print start_html(-title=>"bm_db_login",-bcolor=>"white");
		my $url=url();
		print p ("<b>Biomarker Database</b>");
		print p ("Logged in as: $user");
		print p ("Working directory: $tmp");
# Form to take user into the main part of the db without constantly creating cookie
		print start_form(-method=>"POST",-action=>$url);
		print p (submit(-name=>"function",-value=>"continue"));
		print end_form();
		print end_html();
	}
	else {
# Error message to make sure html header is always supplied
        	print header();
		print start_html(-title=>"bm_db_error",-bcolor=>"white");
		print p ("Username and password incorrect");
		print end_html();
	}
}

sub bm_db_webprompt() {
# Default prompt for username and password
# # Dick Willingale 2008-Jun-10
        print header();
        print start_html(-title=>"bm_db_menu",-bcolor=>"white");
	my $url=url();
	print p ("<b>Biomarker Database</b>");
	print start_form(-method=>"POST",-action=>$url);
	print p ("username:<br>".textfield(-name=>"username"));
	print p ("password:<br>".password_field(-name=>"password"));
	print p (submit(-name=>"function",-value=>"login"));
	print end_form();
	print end_html();
}

sub bm_db_webhome() {
# Home page for logged in user
# # Peter Hague 2008-Jun-16

        print header();
        print start_html(-title=>"bm_db_menu",-bcolor=>"white");
	my $url=url();
	print p ("<b>Biomarker Database</b>");
	print start_form(-id=>"lf",-method=>"POST",-action=>$url,-enctype=>"multipart/form-data"),;
	print p ("<u>Upload a file</u>");
	print p ("Please use the format &lt;project&gt;-&lt;date&gt;-&lt;sample number&gt;&lt;shot letter&gt;.txt, for example mouseplasma-160608-32b.txt");
	print ("Filename:".filefield(-name=>"sourcefile"));
	print (submit(-name=>"function",-value=>"upload"));
	print end_form();
	print start_form(-method=>"POST",-action=>$url);
	print p ("<u>List your current datasets</u>");
	print (submit(-name=>"function",-value=>"list"));
	print end_form();
	print start_form(-method=>"POST",-action=>$url);
	print p ("<u>Change your settings</u>");
	print (submit(-name=>"function",-value=>"settings"));
	print end_html();
}

sub bm_db_webupload($) {
# Script to upload a file to users personal space
# # Peter Hague 2008-Jun-16 

        my ($mode)=@_;
	my $filename=param("sourcefile");
	my (@files,$datfile,$user,$targetdir);

# Determines if the file is being uploaded for the first time, or reloaded
	if ($mode==0) {
	  if (!$filename) { die "Invalid post mode" };

# Normalises windows filenames to make them behave, get rid of : and \
	  $filename=~s/\\/\//g; 
	  $filename=~s/\:/\//g;

# Sanitises the filename so that the script can't be tricked into doing something bad
	  my ($name, $path, $extension)=fileparse($filename,'\..*');
	  $name=~tr/ /_/;
	  $filename=$name.$extension;
	  $filename=~s/[^a-zA-Z0-9_.-]//g;
	  if ($filename=~/^([a-zA-Z0-9_.-]+)$/) { $filename=$1; }
	  else { die "Illegal Filename"; }

# Checks filename follows the biomarker db naming convention
	  if (!($filename=~/[a-zA-Z]+\.zip/)) { die "Invalid file name"; }
	  
	  my $sourcefile_handle=upload("sourcefile");
	  $user=cookie("username");
	  $targetdir=&bm_db_init()."/users/$user";
	
# Creates a new directory and conf file for the dataset
	  mkdir ("$targetdir/$name");
	  &bm_db_newconf($targetdir, $name);
	  $targetdir="$targetdir/$name";

# Writes from source to target file
	  open (TARGETFILE, ">$targetdir/$filename") or die "666 Infernal Server Error";
	  binmode TARGETFILE;
	  while ( <$sourcefile_handle> ) { print TARGETFILE; }
	  close TARGETFILE;

# Unpacks the target file and remove or modify all non-compliant contents
	  system ("unzip -d$targetdir $targetdir/$filename");
	  #unlink ("$targetdir/$filename");
	  &bm_db_normalise($targetdir);
	  my $contents=`ls $targetdir`;
	  #$contents=~s/\W.+[0-9]+[a-zA-Z]\.txt//g;
	  #$contents=~s/\s+$//;
	  #$contents=~s/\s/;rm /g;
	  #system("cd $targetdir; rm -f $contents");
	} else {
	  $targetdir=&bm_db_init()."/users/".cookie("username")."/".param("project");
	}

# Bins uploaded files
	&bm_db_sortall($targetdir, &bm_db_getconf($targetdir,"BinStart"), &bm_db_getconf($targetdir,"BinEnd"), &bm_db_getconf($targetdir,"BinSize"));
	#system ("rm $targetdir/*.txt");

# Removes superfluous .dat files and performs computations on the rest
	unlink($targetdir."/sort_root.dat");
	unlink($targetdir."/sort_parameters.dat");
	@files=glob "$targetdir/*.dat";
	foreach $datfile (@files) { 
	  &bm_db_backsubtract($datfile);
	  $datfile=~s/\.dat/\.csv/;
	  &bm_gaussian($datfile);
	  &bm_db_flux($datfile);
	}

# Combines data into a single file, smooths and extracts features
	&bm_db_combine($targetdir);
	&bm_gaussian($targetdir."/aggregate.csv");
	&bm_db_peaks($targetdir."/aggregate-gs.csv");
	&bm_db_normpks($targetdir."/aggregate-pk.csv");
	&bm_db_arff($targetdir."/aggregate-pk.csv");

	print header();
	print start_html(-title=>"bm_db_upload",-bcolor=>"white");
	my $url=url();
	print p ("<b>Biomarker Database</b>");
	print p ("Logged in as: $user");
	print p ("Working directory: $targetdir");
	print p ("File succesfully uploaded: $targetdir/$filename");
# Returns user to main menu
	print start_form(-method=>"POST",-action=>$url);
	print p (submit(-name=>"function",-value=>"continue"));
	print end_form();
        print end_html();	
}

sub bm_db_weblist() {
# Returns to the user a list of their uploaded datasets
# # Peter Hague 2008-Jun-17
  my $path=&bm_db_init()."/users";
  my $user=cookie("username");
  my $url=url();
  my $file;

  print header();
  print start_html(-title=>"bm_db_list",-bcolor=>"white");
  opendir(USER,"$path/$user");
  while ($file=readdir(USER)) {
    if (opendir(TEST,"$path/$user/$file") && !($file=~/\.+/)) {
      closedir (TEST);
      print '<div class="dataset">'.$file.'</div>';
      print start_form(-method=>"POST",-action=>$url);
      print hidden(-name=>"id",-value=>"$file");
      print submit(-name=>"function",-value=>"examine");
      print end_form();
      print start_form(-method=>"POST",-action=>$url);
      print hidden(-name=>"id",-value=>"$file");
      print submit(-name=>"function",-value=>"delete");
      print end_form();
      print "<br />";
    }
  }
  closedir (USER);
  print end_html();
}

sub bm_db_weblook($) {
# Returns to the user a list of the files in a specified dataset
# # Peter Hague 2008-Jun-17
  my $path=&bm_db_init()."/users";
  my $dlpath=&bm_db_dlpath()."/users";
  my $user=cookie("username");
  my $url=url();
  my ($dir)=@_;
  my $file;

  print header();
  print start_html(-title=>"bm_db_look",-bcolor=>"white");
  opendir(USER,"$path/$user/$dir");
  while ($file=readdir(USER)) {
    if (opendir(TEST,"$path/$user/$dir/$file")) {
      closedir (TEST);
    } elsif ($file=~/(.+)\.csv/) {
      print a({-href=>"$dlpath/$user/$dir/$file"}, "$1<br />");
    }
  }
  closedir (USER);
  print start_form(-method=>"POST",-action=>$url);
  print submit(-name=>"function",-value=>"continue");
  print end_form();
  print end_html();
}

sub bm_db_webkill($) {
# Gets rid of a dataset (no prompting!)
# # Peter Hague 2008-Jun-17
  my $path=&bm_db_init()."/users";  
  my $user=cookie("username");
  my $url=url();
  my ($dir)=@_;

  system("rm -f $path/$user/$dir/*");
  system("rmdir $path/$user/$dir");

  print header();
  print start_html(-title=>"bm_db_kill",-bcolor=>"white");
  print p("$path/$user/$dir");
  print p("Dataset $dir has been deleted");
  print start_form(-method=>"POST",-action=>$url);
  print submit(-name=>"function",-value=>"continue");
  print end_form();
  print end_html();
}

sub bm_db_webstatus($) {
  my $user=cookie("username");
  my ($project)=@_;
  my ($path,$file,$aggs,$gscsv,$flcsv,$csv,$dat,$txt,$progress,$message);

  $path=&bm_db_init()."/users/".$user."/".$project;

  opendir(UPLOAD,$path);
  while ($file=readdir(UPLOAD)) {
    if ($file=~/aggregate/) { $aggs++; }
    if ($file=~/-gs\.csv/) { $gscsv++; }
    if ($file=~/-fl\.csv/) { $flcsv++; }
    if ($file=~/\.csv/) { $csv++; }
    if ($file=~/\.dat/) { $dat++; }
    if ($file=~/sort_/) { $dat--; }
    if ($file=~/a\.txt/) { $txt++; }
  }
  closedir(UPLOAD);

  $csv=($csv-$gscsv)-$flcsv;
  
  if ($dat==0) {
    $progress=$txt;
    $message="Unpacking files";
  } elsif ($csv==0) {
    $progress=($dat/$txt)*100;
    $message="Binning samples";
  } elsif ($gscsv==0) {
    $progress=($csv/$dat)*100;
    $message="Subtracting background";
  } elsif ($flcsv==0) {
    $progress=($gscsv/$csv)*100;
    $message="Applying gaussian smoothing";
  } elsif ($aggs==0) {
    $progress=($flcsv/$gscsv)*100;
    $message="Calculating fluxes";
  } else {
    $progress=$aggs/0.03;
    $message="Aggregating";
  }

  if ($aggs==3) { $message="Complete"; }
  $progress=~/(.+)\./;

  print header();
  print start_html(-title=>"bm_db_status",-bcolor=>"white");
  print "<div id=\"action\">$message</div><div id=\"percent\">$1</div>";
  print end_html();
}

sub bm_db_websettings($) {
  my ($projectname)=@_;
  my $url=url();
  my $path=&bm_db_init()."/users/".cookie("username")."/"; 
  my @projects=('<default>');
  my ($file, $projpath);

  opendir(USER,$path);
  while ($file=readdir(USER)) {
    if (opendir(TEST,"$path/$file")) {
      closedir (TEST);
      if (!($file=~/^\.+$/)) { 
	push (@projects, $file);
      }
    } 
  }
  closedir USER;

  $projpath=$path;
  if ($projectname ne "<default>") { $projpath.=$projectname."/"; }

  my $js = "function getvals() {
var project=document.getElementById(\"projectsel\").value;
document.getElementById(\"phandle\").value=project;
document.getElementById(\"form2\").submit();
}"; 

  print header();
  print start_html(-title=>"bm_db_settings",-bcolor=>"white", -script=>{-code=>$js});
  print p("Change your settings");
  print start_form(-method=>"POST", -action=>$url, -id=>"form1");
  print p("<u>Target project</u>");
  print p(popup_menu(-name=>"project", -values=>\@projects,-defaults=>['<default>'], -onChange=>"getvals()", -id=>"projectsel"));
  print p("<u>Binning parameters</u>");
  print "Start bin:".textfield(-name=>"BinStart", -value=>(&bm_db_getconf($projpath, "BinStart")+&bm_db_getconf($projpath, "BinSize")/2));
  print "End bin:".textfield(-name=>"BinEnd", -value=>(&bm_db_getconf($projpath, "BinEnd")+&bm_db_getconf($projpath, "BinSize")/2));
  print "Bin size:".textfield(-name=>"BinSize", -value=>&bm_db_getconf($projpath, "BinSize"));
  print p("<u>Background subtraction parameters</u>");
  print "Window Size:".textfield(-name=>"WindowSize", -value=>&bm_db_getconf($projpath, "WindowSize"));
  print "Threshold:".textfield(-name=>"Threshold", -value=>&bm_db_getconf($projpath, "Threshold"));
  print p("<u>Peak extraction parameters</u>");
  print "Sigma value (for preliminary smoothing only):".textfield(-name=>"Sigma", -value=>&bm_db_getconf($projpath, "Sigma"));
  print "Minimum significance:".textfield(-name=>"Significance", -value=>&bm_db_getconf($projpath, "Significance"));
  print p("<u>Normalisation parameters</u>");
  print "Minimum flux for normalisation:".textfield(-name=>"MinFlux", -value=>&bm_db_getconf($projpath, "MinFlux"));
  print "Maximum flux for normalisation:".textfield(-name=>"MaxFlux", -value=>&bm_db_getconf($projpath, "MaxFlux"));
  print "Maximum scatter for normalisation:".textfield(-name=>"MaxScatter", -value=>&bm_db_getconf($projpath, "MaxScatter"));
  print p(submit(-name=>"function",-value=>"apply"));
  print end_form();
  print start_form(-method=>"POST", -action=>$url, -id=>"form2");
  print hidden(-name=>"function", -value=>"settings");
  print hidden(-name=>"project", -value=>"<default>", -id=>"phandle");
  print end_form();
  print end_html();
}

sub bm_db_websave() {
  my $url=url();
  my $path=&bm_db_init()."/users/".cookie("username")."/"; 
  my $BinSize=param("BinSize");
  my $BinStart=param("BinStart")-param("BinSize")/2;
  my $BinEnd=param("BinEnd")-param("BinSize")/2;

  if (param("project") ne "<default>") { $path.=param("project")."/"; }

  open(SPECCONF,">".$path."spec.conf") or die("666 Infernal Server Error: ".$path."spec.conf not found");
  print SPECCONF "#Binning parameters\n";
  print SPECCONF "BinStart ".$BinStart."\n";
  print SPECCONF "BinEnd ".$BinEnd."\n";
  print SPECCONF "BinSize ".$BinSize."\n\n";
  print SPECCONF "#Background substraction parameters\n";
  print SPECCONF "WindowSize ".param("WindowSize")."\n";
  print SPECCONF "Threshold ".param("Threshold")."\n\n";
  print SPECCONF "#Peak significance\n";
  print SPECCONF "Sigma ".param("Sigma")."\n";
  print SPECCONF "Significance ".param("Significance")."\n\n";
  print SPECCONF "#Normalisation\n";
  print SPECCONF "MinFlux ".param("MinFlux")."\n";
  print SPECCONF "MaxFlux ".param("MaxFlux")."\n";
  print SPECCONF "MaxScatter ".param("MaxScatter")."\n";
  close SPECCONF;

  if (param("project") ne "<default>") { &bm_db_webupload(1); }

  print header();
  print start_html(-title=>"bm_db_save",-bcolor=>"white");
  print start_form(-method=>"POST",-action=>$url);
  print p("Settings changed in ".$path."spec.conf");
  print p(submit(-name=>"function",-value=>"continue"));
  print end_form();
  print end_html();
}

END { }
1;
