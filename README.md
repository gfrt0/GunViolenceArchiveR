# GunViolenceArchiveR
**[Giuseppe Forte](mailto:giuseppe[dot]forte[at]economics.ox.ac.uk), University of Oxford**

## Purpose
1. To collect in a dataset the information on gunshot incidents that currently
has to be queried on the [Gun Violence Archive](https://www.gunviolencearchive.org).

## Inputs and output
The data comes from the [Gun Violence Archive](https://www.gunviolencearchive.org), a non-profit that collects, checks, and disseminates information on gun-related incidents in the United States. While their work is extremely important, I have found obtaining large amount of data from their website to be complicated for a human: this is chiefly the result of the lack of a "batch download" option and the limit on the incidents reported by each query. The task is however fairly straightforward for a machine.

For the period from 1/1/2014 onwards, the code creates monthly .csv tables containing (if available) information on:
* Date of the incident
* State
* Location (County or locality)
* Address
* Number of persons killed
* Number of persons injured
* Incident identification code
* Source of the news

In the near future, the code will also include further characteristics contained in each incident-specific webpage.

## Limitations
GVA has a very broad definition of gun violence, and the number of incidents is very large as a result (see [here](https://www.gunviolencearchive.org/methodology) for a discussion of their methodology). Care must be taken in comparing the numbers resulting from GVA data with other sources as a result. See [here](https://www.thetruthaboutguns.com/2015/01/foghorn/gun-violence-archive-flawed-start/) for an example of a piece criticising the GVA methodology. In any case, I think the data is interesting; I do not have an opinion on whether it is correct, and for what purposes.

## Other
This is a very simple two-day project that I put together to teach myself some [seleniumPipes](https://cran.r-project.org/web/packages/seleniumPipes/vignettes/basicOperation.html). While the code is freely available for others to look at, modify, and use (with attribution, maybe), I do not encourage others to burden the GVA website - especially if you can simply use the data included in the repository.