# Reducing Allocations & Optimisation Example

This repository contains code for running a real time N-body simulation. In order to run the code, you must have Julia installed and then follow the instructions below.

## Getting Started

First, download this code locally by cloning this repository. Then, open up a terminal and `cd` into this repository. Once there, run the following command:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

This will download and install all the packages required to run this code. This might take some time to install and precompile everything, but only needs to be done once.

To run the code, type the following into the terminal:
```bash
julia --project main.jl
```

If you want to change the number of particles, you can modify the final line in `main.jl`.

## Optimising this code

Feel free to try and optimise this code even further, or try to follow along with the videos. If you want to modify the code, I would suggest creating a fork of this repository and making changes there.

## Notes

I have included the [`Roboto`](https://github.com/googlefonts/roboto-3-classic) font inside the `data` folder along with its license. I do not own this font, and the MIT license for this repository does not apply to this font, with is governed by its own license (OFL).