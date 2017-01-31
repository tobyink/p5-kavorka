# Kavorka

Function signatures with the lure of the animal

## Installation

The best way to install Kavorka is via `cpanm`:

    $ cpanm Kavorka

Alternative installation instructions can be found in the `INSTALL` file in
the CPAN distribution tarball.

## Building from source

Clone the source:

    $ git clone https://github.com/tobyink/p5-kavorka.git
    $ cd p5-kavorka

Install the dependencies:

    $ cpanm Dist::Inkt Dist::Inkt::Profile::TOBYINK \
            Parse::Keyword namespace::sweep Data::Alias Return::Type
            Moops Text::sprintfn
    $ cpanm -U Kavorka  # installed as a dependency of Moops

Run the distribution build program:

    $ distinkt-dist     # builds the dist tarball and runs the test suite

## Running the test suite

One can simply run `prove` in the usual manner:

    $ prove -lr t
