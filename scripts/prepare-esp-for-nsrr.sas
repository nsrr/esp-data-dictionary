*******************************************************************************;
* Program           : prepare-esp-for-nsrr.sas
* Project           : National Sleep Research Resource (sleepdata.org)
* Author            : Michael Rueschman (mnr)
* Date Created      : 20181210
* Purpose           : Prepare ESP data for posting on NSRR.
* Revision History  :
*   Date      Author    Revision
*
*******************************************************************************;

*******************************************************************************;
* establish options and libnames ;
*******************************************************************************;
  options nofmterr;
  data _null_;
    call symput("sasfiledate",put(year("&sysdate"d),4.)||put(month("&sysdate"d),z2.)||put(day("&sysdate"d),z2.));
  run;

  *define primary path;
  %let esppath = \\rfawin\bwh-sleepepi-nsrr-sandbox\nimh-esp\nsrr-prep;

  *project source datasets;
  libname esps "&esppath\_source";

  *output location for nsrr sas datasets;
  libname espd "&esppath\_datasets";
  libname espa "&esppath\_archive";

  *nsrr id location;
  libname espi "&esppath\_ids";

  *set data dictionary version;
  %let version = 0.1.0;

  *set nsrr csv release path;
  %let releasepath = &esppath\_releases;

*******************************************************************************;
* create core dataset ;
*******************************************************************************;


*******************************************************************************;
* make all variable names lowercase ;
*******************************************************************************;
  options mprint;
  %macro lowcase(dsn);
       %let dsid=%sysfunc(open(&dsn));
       %let num=%sysfunc(attrn(&dsid,nvars));
       %put &num;
       data &dsn;
             set &dsn(rename=(
          %do i = 1 %to &num;
          %let var&i=%sysfunc(varname(&dsid,&i));    /*function of varname returns the name of a SAS data set variable*/
          &&var&i=%sysfunc(lowcase(&&var&i))         /*rename all variables*/
          %end;));
          %let close=%sysfunc(close(&dsid));
    run;
  %mend lowcase;

  %lowcase(espbaseline_nsrr);
  %lowcase(espmonth1_nsrr);
  %lowcase(espmonth3_nsrr);

*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data espd.espbaseline espa.espbaseline_&sasfiledate;
    set espbaseline_nsrr;
  run;

  data espd.espmonth1 espa.espmonth1_&sasfiledate;;
    set espmonth1_nsrr;
  run;

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=espbaseline_nsrr
    outfile="&releasepath\&version\esp-baseline-dataset-&version..csv"
    dbms=csv
    replace;
  run;

  proc export data=espmonth1_nsrr
    outfile="&releasepath\&version\esp-month1-dataset-&version..csv"
    dbms=csv
    replace;
  run;
