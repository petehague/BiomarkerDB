Biomarkers Database 
===================

This is a bioinformatic code I produced in 2008 for the Department of Cancer Studies at the University of Leicester with Dick Willingale (Department of Physics and Astronomy). The goal is to extract peaks from mass spectrometry data, and the present the peak data through a web interface.

Installing the Biomarkers database
----------------------------------

Firstly ensure your web server is functional, and able to run perl scripts from at least on folder.

1. Copy the Biomarkers folder into the a folder used by your web server
2. Copy the file bm_db_web.pl into your cgi-bin folder (or equivalent)
3. Edit bm_db_web.pl so that it can find the folder containing your BM*.pm files
4. Edit BMINIT.pm so that it can find your user directories.

When installation is complete, the following files should be found in the folder 'Biomarkers'

For the back end script:
BMDBI.pm - main subroutine, handles user interactions
BMARFF.pm - script for converting to ARFF format files
BMBACKSUB.pm - applies background subtraction
BMCONF.pm - script for retrieving and writing configuration data
BMFLUX.pm - calculates flux under peaks
BMGAUSS.pm - performs gaussian blurring
BMINIT.pm - initialises global variables for other scripts (this may need editing when database is moved)
BMNORM.pm - normalises file names
BMPEAKS.pm - extracts peak data
BMSORT.pm - sorts files
BMSTATUS.pm - returns status reports

And for the front end:
interface.html - the main page of the front end
main.css - stylesheet for the front end
javascript/main.js - javascript routines for the front end

And finally, user information
user/spec.conf - contains information script uses to guide data processing
user/sigma.conf - not currently used

The file bm_db_web.pl should be placed in a folder that your web server will allow scripts to be run from (normally cgi-bin) and edited so that it refers to the folder containing the BM*.pm files.


Security
--------

This system is not designed to protect sensitive data from determined attackers. It is not intended for use on the public wed as it is. 