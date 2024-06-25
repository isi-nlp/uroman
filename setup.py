#!/usr/bin/env python3

import uroman.uroman
from uroman.uroman import __version__, __description__
from pathlib import Path

from setuptools import setup, find_namespace_packages

long_description = Path('README.md').read_text(encoding='utf-8', errors='ignore')

classifiers = [  # copied from https://pypi.org/classifiers/
    'Development Status :: 4 - Beta',
    'Intended Audience :: Developers',
    'Topic :: Utilities',
    'Topic :: Text Processing',
    'Topic :: Text Processing :: General',
    'Topic :: Text Processing :: Linguistic',
    'License :: OSI Approved :: Apache Software License',
    'Programming Language :: Python :: 3 :: Only',
]

setup(
    name='uroman',
    version=__version__,
    description=__description__,
    long_description=long_description,
    long_description_content_type='text/markdown',
    classifiers=classifiers,
    python_requires='>=3.10',
    url='https://github.com/isi-nlp/uroman',
    download_url='https://github.com/isi-nlp/uroman',
    platforms=['any'],
    author='Ulf Hermjakob',
    author_email='ulf@isi.edu',
    packages=find_namespace_packages(exclude=['aux', 'lib', 'old']),
    keywords=['machine translation', 'romanization', 'NLP', 'natural language processing,'
              'computational linguistics', 'string similarity'],
    entry_points={
        'console_scripts': [
            'uroman.py=uroman.uroman:main',
        ],
    },
    install_requires=[
        'regex>=2024.5.15',
    ],
    include_package_data=True,
    zip_safe=False,
)
