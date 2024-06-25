# Release instructions 

Using twine : https://twine.readthedocs.io/en/latest/ 

1. Update the `__version__` and `__last_mod_date__` in `uroman.py`  
   Clear `rm -r build dist *.egg-info`   if those dir exist.
2. Build :: `$ python setup.py sdist bdist_wheel`   
   where `sdist` is source code; `bdist_wheel` is universal ie. for all platforms
3. Upload to **testpypi** ::  `$ python3 -m twine upload --repository testpypi dist/*`
4. Upload to **pypi** ::  `$ python3 -m twine upload --repository pypi dist/*`


### The `.pypirc` file

The rc file `~/.pypirc` should have something like this 
```ini
[distutils]
index-servers =
    pypi
    testpypi

[pypi]
repository: https://upload.pypi.org/legacy/
username: uhermjakob
password: <password_here>


[testpypi]
repository: https://test.pypi.org/legacy/
username: uhermjakob
password: <password_here>
```
