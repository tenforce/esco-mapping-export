# ESCO EXPORT SERVICE

This service provides an endpoint from which you can get a CSV/TSV
that contains an entry for every mapping of a given mapping effort.

## API

We only have a single route: /export. When a GET call is performed to this
endpoint it returns a comma separated list (or a TSV if requested) of every
mapping.

### String Arguments

 *  format

    Can be either: text/csv or text/tab-separated-values

 *  uuid

    The UUID of the mapping effort

#### Example

```
curl -s "http://localhost/export?format=text/csv&uuid=2cbcbea3-411a-40ec-88e7-d06eb0c57baf"
```
