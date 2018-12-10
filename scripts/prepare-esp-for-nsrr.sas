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
  %let version = 0.1.0.pre;

  *set nsrr csv release path;
  %let releasepath = \\rfawin\bwh-sleepepi-nsrr-sandbox\nimh-esp\nsrr-prep\_releases;

*******************************************************************************;
* create core dataset ;
*******************************************************************************;
  proc import datafile="&esppath\_source\Copy of 11-M-0144_Comprehensive_Behavioral_v7 data for NSRR 11-8-18.xlsx"
    out=espnsrr_in
    dbms=xlsx
    replace;
  run;

  data espnsrr;
    length nsrrid visitnumber intervalmonth subjectrole 8.;
    set espnsrr_in;

    nsrrid = input(substr(subject_number,1,3),8.);
    visitnumber = input(substr(subject_number,5,1),8.);
    intervalmonth = input(substr(Interval,1,2),8.);
    if subject_role = "Typical" then subjectrole = 2;
    else if subject_role = "Language Delay" then subjectrole = 3;

    keep nsrrid visitnumber intervalmonth subjectrole race ethnicity edu_mother
      sex BISQ_VISIT_AGE BISQ_SLEEP_ARRANGMENT BISQ_SLEEP_POSITION;
  run;

  data espnsrr_visit1;
    set espnsrr;

    if visitnumber = 1;
  run;

  proc sort data=espnsrr_visit1;
    by nsrrid;
  run;

  data espnsrr_visit2;
    set espnsrr;

    if visitnumber = 2;
  run;

  proc sort data=espnsrr_visit2;
    by nsrrid;
  run;

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

  %lowcase(espnsrr_visit1);
  %lowcase(espnsrr_visit2);

*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data espd.espvisit1 espa.espvisit1_&sasfiledate;
    set espnsrr_visit1;
  run;

  data espd.espvisit1 espa.espvisit1_&sasfiledate;;
    set espnsrr_visit2;
  run;

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=espnsrr_visit1
    outfile="&releasepath\&version\esp-visit1-dataset-&version..csv"
    dbms=csv
    replace;
  run;

  proc export data=espnsrr_visit2
    outfile="&releasepath\&version\esp-visit2-dataset-&version..csv"
    dbms=csv
    replace;
  run;
