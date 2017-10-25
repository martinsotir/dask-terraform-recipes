FROM continuumio/miniconda3:4.3.27

# source: https://github.com/dask/dask-docker/blob/master/base/Dockerfile

RUN conda create -n dask --yes -c conda-forge \
    dask distributed numpy scipy pandas numba nomkl fastparquet s3fs zict bcolz blosc cytoolz \
    && conda clean -tipsy
    
ENV PATH=/opt/conda/envs/dask/bin:$PATH

CMD ["bash"]