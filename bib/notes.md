## Bechhofer et al. (2010)

Research Objects: Towards Exchange and Reuse of Digital Knowledge

### Objectives

Research Object = rich aggregations of resources that provide the “units of knowledge"
= data + methods + people

- “borrow strength" from other research
- framework that facilitates the reuse and exchange of digital knowledge

digital exchange of data → straightforward
digital exchange of knowledge → non-trivial

goal = create a class of artefacts that can encapsulate our digital knowledge and provide
a mechanism for sharing and discovering assets of reuseable research and scientific knowledge.

Reusable 
Repurposeable = reuse constituent parts (for another purpose)
Repeatable = other can repeat the same study (data + services)
Reproducible = use same material and methods and see if the same results can be obtained
Replayable = metadata recording the provenance of data and results
Traceability = 

## Wilkinson et al. (2016)

### Objective

reuse of data alone or with newly acquired data
> "Collect once, use many times"

machines to automatically find and use the data
 
Not only data but also other research objects
- algorithms
- tools, and 
- analytical workflows 
that led to that data.

ALL research objects!

both for human and machine

### Origin

"Jointly Designing a Data Fairport" workshop in 2014


### Examples

* Dataverse (https://dataverse.org): Open source research data repository software; unbreakable link between articles in your journal and associated data
* FigShare (http://figshare.com): stores any type of file and visualizes hundreds of file formats; allow for sharing and publish research objects
* Dryad (https://datadryad.or): data in any file format from any field of research to satisfy publisher and funder requirements for preservation and availability
* Mendeley Data (https://data.mendeley.com): free and secure cloud-based communal repository where you can store your data
* Zenodo (http://zenodo.org): house closed and restricted content, so that artefacts can be captured and stored safely 
* DataHub (http://datahub.io): easily publish and share datasets from GitHub
* DANS (http://www.dans.knaw.nl): Data Archiving and Network Service; not widely used in oceanography
* EUDAT (https://www.eudat.eu): address the full lifecycle of research data
* FAIRDOM (https://fair-dom.org):  data, documents operating procedures and models

__Issue__ few restrictions on the dataset → less integration



## DOI

DOI = 
- most widely known and used PIDs. 
- designed for research objects

Structure: resolver service / assigning body / resource

Managed by the Registration Agencies

Alternative metrics

## White et al. (2013)

Nine simple ways to make it easier to (re)use your data

### Objectives

making your data
- understandable
- easy to work with
- available to the wider community of scientists. 

1. Share → required by funding agencies, journals and by law
2. Provide metadata → standards
3. Provide raw data → more flexibility
4. Use standard data formats → files, tables, cells...
5. Use good null values
6. Make it easy to combine your data with other datasets
7. Perform basic quality control
8. Use an established repository → http://databib.org and http://re3data.org
9. Use an established and open license

## Sandve (2013)

Ten Simple Rules for Reproducible Computational Research

reproducible research 
replication: clear protocol
culture of reproducibility

good habits of reproducibility may actually turn out to be a time-saver in the longer run.

exponential number of possible combinations of 
- software versions, 
- parameter values, 
- pre-processing steps

__Benefits:__ increase trust and citation

### Rules

1. For Every Result, Keep Track of How It Was Produced → workflow, versionning
2. Avoid Manual Data Manipulation Steps → copy/paste etc
3. Archive the Exact Versions of All External Programs Used → code, packages, dependencies, ... virtual machine
4. Version Control All Custom Scripts
5. Record All Intermediate Results, When Possible in Standardized Formats → re-running code, finding errors
6. For Analyses That Include Randomness, Note Underlying Random Seeds → 
7. Always Store Raw Data behind Plots → store also code to produce the code
8. Generate Hierarchical Analysis Output, Allowing Layers of Increasing Detail to Be Inspected 
9. Connect Textual Statements to Underlying Results
10. Provide Public Access to Scripts, Runs, and Results

> As a minimum, you should submit the main data and source code as supplementary material, and be prepared to respond to any requests for further data or methodology details by peers.

## FAIR assessment tools

* Devaraju, A., & Huber, R. (2023). F-UJI - An Automated FAIR Data Assessment Tool. Zenodo. https://doi.org/10.5281/zenodo.6361400

* Vesa Akerman, Linas Cepinskas, Maaike Verburg, & Mokrane Mustapha. (2021). FAIR-Aware: Assess Your Knowledge of FAIR (v1.0.1). Zenodo. https://doi.org/10.5281/zenodo.5084861 

### FAIR Assessment Tools: Towards an “Apples to Apples” Comparisons

Same DO assessment by different tools often exhibits widely different results

FAIR assessment tool creators had no guidance on how to apply metrics to a digital object. 

## References (to add to BibTeX)

[x] Crosas, M. "The Dataverse Network®: An Open-Source Application for Sharing, Discovering and Preserving Data". D-Lib Mag 17 (1), p2 (2011).

[x] White, H. C., Carrier, S., Thompson, A., Greenberg, J. & Scherle, R. The Dryad data repository: A Singapore framework metadata architecture in a DSpace environment. Univ. Göttingen, p157 (2008).

[x] Lecarpentier, D. et al. EUDAT: A New Cross-Disciplinary Data Infrastructure for Science. Int. J. Digit. Curation 8, 279–287 (2013).

[x] White, E. et al. Nine simple ways to make it easier to (re)use your data. Ideas Ecol. Evol. 6 (2013).

-- Sandve, G. K., Nekrutenko, A., Taylor, J. & Hovig, E. Ten Simple Rules for Reproducible Computational Research. PLoS Comput. Biol. 9, e1003285 (2013).


## Application

EMODnet Chemistry Eutrophication - Mediterranean Sea

https://emodnet.ec.europa.eu/en/eutrophication

Testing with F-UJI:

1) With the DOI: 10.6092/ep6n-tp63 → 58%
2) https://sextant.ifremer.fr/documentation/emodnet_chemistry/api/catalogue.html#/metadata/a6d89ed2-17d0-4a8a-97fe-7e99d8e6520d → 4% ???
3) https://emodnet.ec.europa.eu/geonetwork/emodnet/eng/catalog.search#/metadata/74158cb0-a21f-42ea-8a29-72a96b2a0da2 → 8%
4) 