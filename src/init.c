
/* 
   Native symbol registration table for spatstat.core package

   Automatically generated - do not edit this file!

*/

#include "proto.h"
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/*  
   See proto.h for declarations for the native routines registered below.
*/

static const R_CMethodDef CEntries[] = {
    {"acrdenspt",        (DL_FUNC) &acrdenspt,        10},
    {"acrsmoopt",        (DL_FUNC) &acrsmoopt,        10},
    {"adenspt",          (DL_FUNC) &adenspt,           7},
    {"asmoopt",          (DL_FUNC) &asmoopt,           8},
    {"awtcrdenspt",      (DL_FUNC) &awtcrdenspt,      11},
    {"awtcrsmoopt",      (DL_FUNC) &awtcrsmoopt,      11},
    {"awtdenspt",        (DL_FUNC) &awtdenspt,         8},
    {"awtsmoopt",        (DL_FUNC) &awtsmoopt,         9},
    {"Cclosepaircounts", (DL_FUNC) &Cclosepaircounts,  5},
    {"Ccrosspaircounts", (DL_FUNC) &Ccrosspaircounts,  8},
    {"Cidw",             (DL_FUNC) &Cidw,             14},
    {"Cidw2",            (DL_FUNC) &Cidw2,            16},
    {"crdenspt",         (DL_FUNC) &crdenspt,          9},
    {"crsmoopt",         (DL_FUNC) &crsmoopt,         10},
    {"delta2area",       (DL_FUNC) &delta2area,       10},
    {"denspt",           (DL_FUNC) &denspt,            6},
    {"digberJ",          (DL_FUNC) &digberJ,           6},
    {"Ediggatsti",       (DL_FUNC) &Ediggatsti,       10},
    {"Ediggra",          (DL_FUNC) &Ediggra,          11},
    {"Efiksel",          (DL_FUNC) &Efiksel,           9},
    {"Egeyer",           (DL_FUNC) &Egeyer,           11},
    {"ESdiggra",         (DL_FUNC) &ESdiggra,         12},
    {"Gdenspt",          (DL_FUNC) &Gdenspt,           5},
    {"Gsmoopt",          (DL_FUNC) &Gsmoopt,           7},
    {"Gwtdenspt",        (DL_FUNC) &Gwtdenspt,         6},
    {"Gwtsmoopt",        (DL_FUNC) &Gwtsmoopt,         8},
    {"idwloo",           (DL_FUNC) &idwloo,            8},
    {"idwloo2",          (DL_FUNC) &idwloo2,          10},
    {"KborderD",         (DL_FUNC) &KborderD,          8},
    {"KborderI",         (DL_FUNC) &KborderI,          8},
    {"KnoneD",           (DL_FUNC) &KnoneD,            6},
    {"KnoneI",           (DL_FUNC) &KnoneI,            6},
    {"KrectDbl",         (DL_FUNC) &KrectDbl,         17},
    {"KrectInt",         (DL_FUNC) &KrectInt,         17},
    {"KrectWtd",         (DL_FUNC) &KrectWtd,         18},
    {"Kwborder",         (DL_FUNC) &Kwborder,          9},
    {"Kwnone",           (DL_FUNC) &Kwnone,            7},
    {"locpcfx",          (DL_FUNC) &locpcfx,          12},
    {"locprod",          (DL_FUNC) &locprod,           7},
    {"locWpcfx",         (DL_FUNC) &locWpcfx,         13},
    {"locxprod",         (DL_FUNC) &locxprod,         10},
    {"RcallF3",          (DL_FUNC) &RcallF3,          17},
    {"RcallF3cen",       (DL_FUNC) &RcallF3cen,       20},
    {"RcallG3",          (DL_FUNC) &RcallG3,          17},
    {"RcallG3cen",       (DL_FUNC) &RcallG3cen,       19},
    {"RcallK3",          (DL_FUNC) &RcallK3,          17},
    {"Rcallpcf3",        (DL_FUNC) &Rcallpcf3,        18},
    {"ripboxDebug",      (DL_FUNC) &ripboxDebug,      11},
    {"ripleybox",        (DL_FUNC) &ripleybox,        11},
    {"ripleypoly",       (DL_FUNC) &ripleypoly,       12},
    {"rippolDebug",      (DL_FUNC) &rippolDebug,      12},
    {"scantrans",        (DL_FUNC) &scantrans,        11},
    {"segdens",          (DL_FUNC) &segdens,          10},
    {"segwdens",         (DL_FUNC) &segwdens,         11},
    {"smoopt",           (DL_FUNC) &smoopt,            8},
    {"wtcrdenspt",       (DL_FUNC) &wtcrdenspt,       10},
    {"wtcrsmoopt",       (DL_FUNC) &wtcrsmoopt,       11},
    {"wtdenspt",         (DL_FUNC) &wtdenspt,          7},
    {"wtsmoopt",         (DL_FUNC) &wtsmoopt,          9},
    {NULL, NULL, 0}
};

void R_init_spatstat_core(DllInfo *dll)
{
    R_registerRoutines(dll, CEntries, NULL, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE); 
}
