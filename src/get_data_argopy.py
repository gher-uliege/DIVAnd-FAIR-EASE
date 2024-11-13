
from argopy import DataFetcher as ArgoDataFetcher

ds = ArgoDataFetcher().region([12., 18., 43., 46., 0, 500, '1950-01', '2024-12']).to_xarray()