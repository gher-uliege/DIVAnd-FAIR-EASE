

Token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvZGF0YS5ibHVlLWNsb3VkLm9yZyIsImF1ZCI6Imh0dHBzOlwvXC9kYXRhLmJsdWUtY2xvdWQub3JnIiwiaWF0IjoxNzI0NjY1OTkyLCJleHAiOjE3NTYyMDE5OTIsInVzciI6MTMxLCJpZCI6ImN0cm91cGluQHVsaWVnZS5iZSIsImVwX29yZ2FuaXNhdGlvbiI6IlVuaXZlcnNpdHkgb2YgTGlcdTAwZThnZSJ9.28HOmAZ71IrMPioxbESq9nDY-rFPxVi6B_yAzT51_eY'

import requests
import json
import datetime

parameter = "TEMP"
mintemp = datetime.date(2010, 1, 1)
maxtemp = datetime.date(2012, 1, 1)
minlon = 12.
maxlon = 18.
minlat = 43.
maxlat = 46.
mindepth = 0.
maxdepth = 10. 

dateref = datetime.date(1950, 1, 1) #Days since 1950
mintemporal = (mintemp - dateref).days #Days since 1950
maxtemporal = (maxtemp - dateref).days #Days since 1950
regionname = f'[{minlat},{minlon}],[{maxlat},{maxlon}]' 

def query(parameter, mintemporal, maxtemporal, mindepth, maxdepth, minlon, maxlon, minlat, maxlat):
    body = {
        "query_parameters": [
            {
                "column_name": parameter,
                "alias": parameter
            },
            {
                "column_name": "JULD",
                "alias": "TIME" 
            },
            {
                "column_name": "DEPH",
                "alias": "DEPTH"
            },
            {
                "column_name": "LONGITUDE",
                "alias": "LONGITUDE"
            },
            {
                "column_name": "LATITUDE",
                "alias": "LATITUDE"
            }
        ],
        "filters": [
            {
              "for_query_parameter": "TIME",
              "min": mintemporal,
              "max": maxtemporal
            },
            {
              "for_query_parameter": "DEPTH",
              "min": mindepth,
              "max": maxdepth
            },
            {
              "for_query_parameter": "LONGITUDE",
              "min": minlon,
              "max": maxlon
            },
            {
              "for_query_parameter": "LATITUDE",
              "min": minlat,
              "max": maxlat
            },
            {
              "for_query_parameter": parameter,
              "min": -2.0,
              "max": 30.0
            }
        ],
        "output": {
            "format": "netcdf"
        }}
    return body

query = query(parameter, mintemporal, maxtemporal, mindepth, maxdepth, minlon, maxlon, minlat, maxlat)

response = requests.post("https://beacon-cora-ts.maris.nl/api/query", json.dumps(query), headers = {
    'Authorization' : f'Bearer {Token}',
    'Content-type': 'application/json'
})
