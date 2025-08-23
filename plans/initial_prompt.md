Please help implement a new Ruby gem here. Use `/Users/trex22/development/url_categorise` as an example. The Version should be 0.0.1. Here is the API documentation: @https://www.kaggle.com/docs/api . Also here is another context resource: @https://github.com/Kaggle/kaggle-api. Create a new plan in plans/. For now the gem should only handle downloading and parsing datasets. For now only open CSV datasets into a json structure. Allow for optional parameters to specify download paths and caching paths as this gem will be used elsewhere where we want a cache download location so that the dataset does not always have to be downloaded. Create and update a README.md with relevant info and use `/Users/trex22/development/url_categorise` as an example. Also add in tests using `/Users/trex22/development/url_categorise` as an example with relevant bin/ scripts. Add in a CLAUDE.md as well. Lastly, update the plans with new plans for future development which include, CLI tool, lists, models, benchmarks etc ...

List and plan out all actions before actioning.

Use the oj gem version 3.16.11 instead of the ruby json library. Also please increase test        │
│   coverage and fix the failing tests. Also copy codes of conduct from                               │
│   /Users/trex22/development/url_categorise/.


Oj has a slightly different interface: https://github.com/ohler55/oj

