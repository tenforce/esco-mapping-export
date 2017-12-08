require "sparql/client"
require "uri"

queryFindMappingEffort = <<QUERY
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>
PREFIX mu: <http://mu.semte.ch/vocabularies/core/>

SELECT ?mappingEffort
FROM <#{settings.graph}>
WHERE
{
  ?mappingEffort a mp:MappingEffort ;
  mu:uuid %uuid% .
}
QUERY

queryFromEsco = <<QUERY
PREFIX esco: <http://data.europa.eu/esco/model#>
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>
PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
PREFIX skosxl: <http://www.w3.org/2008/05/skos-xl#>

SELECT ?nocID ?nocPrefLabel ?escoURI ?escoPrefLabel ?mappingType ?status
FROM <#{settings.graph}>
WHERE
{
  ?mapping a mp:Mapping ;
  mp:isMappingFor <%mappingEffort%> ;
  mp:mapsFrom ?escoURI ;
  mp:mapsTo ?nocURI ;
  mp:matchType ?mappingType ;
  mp:status ?status .

  OPTIONAL { ?escoURI skosxl:prefLabel/skosxl:literalForm ?escoPrefLabel } .

  ?nocURI esco:NOCID ?nocID .
  OPTIONAL { ?nocURI skosxl:prefLabel/skosxl:literalForm ?nocPrefLabel } .
}
QUERY

queryToEsco = <<QUERY
PREFIX esco: <http://data.europa.eu/esco/model#>
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>
PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
PREFIX skosxl: <http://www.w3.org/2008/05/skos-xl#>

SELECT ?nocID ?nocPrefLabel ?escoURI ?escoPrefLabel ?mappingType ?status
FROM <#{settings.graph}>
WHERE
{
  ?mapping a mp:Mapping ;
  mp:isMappingFor <%mappingEffort%> ;
  mp:mapsFrom ?nocURI ;
  mp:mapsTo ?escoURI ;
  mp:matchType ?mappingType ;
  mp:status ?status .

  OPTIONAL { ?escoURI skosxl:prefLabel/skosxl:literalForm ?escoPrefLabel } .

  ?nocURI esco:NOCID ?nocID .
  OPTIONAL { ?nocURI skosxl:prefLabel/skosxl:literalForm ?nocPrefLabel } .
}
QUERY

queryIsMappingToNoc = <<QUERY
PREFIX esco: <http://data.europa.eu/esco/model#>
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>
PREFIX mu: <http://mu.semte.ch/vocabularies/core/>

ASK
FROM <#{settings.graph}>
{
  ?mapping a mp:Mapping ;
  mp:isMappingFor <%mappingEffort%> ;
  mp:mapsTo/esco:NOCID ?x .
}
QUERY

queryFetchHeadersToNoc = <<QUERY
PREFIX esco: <http://data.europa.eu/esco/model#>
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>

SELECT ?key ?value
FROM <#{settings.graph}>
WHERE
{
  {
    SELECT ("Mapping version:" AS ?key) (?mappingVersion AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:mappingVersion ?mappingVersion .
    }
  }
  UNION
  {
    SELECT ("From URI:" AS ?key) (?fromUri AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:taxonomyFrom ?fromUri .
    }
  }
  UNION
  {
    SELECT ("To ID:" AS ?key) (?toId AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsTo/esco:NOCClassification ?toId .
    }
    LIMIT 1
  }
  UNION
  {
    SELECT ("To version:" AS ?key) (?toVersion AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsTo/esco:NOCVersion ?toVersion .
    }
    LIMIT 1
  }
  UNION
  {
    SELECT ("To type:" AS ?key) (?toType AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:taxonomyTo ?toUri .
      ?toUri esco:NOCConceptType ?toType .
    }
  }
  UNION
  {
    SELECT ("Language:" AS ?key) (?language AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsTo/esco:referenceLanguage ?language .
    }
    LIMIT 1
  }
}
QUERY

queryFetchHeadersFromNoc = <<QUERY
PREFIX esco: <http://data.europa.eu/esco/model#>
PREFIX mp: <http://sem.tenforce.com/vocabularies/mapping-platform/>

SELECT ?key ?value
FROM <#{settings.graph}>
WHERE
{
  {
    SELECT ("Mapping version:" AS ?key) (?mappingVersion AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:mappingVersion ?mappingVersion .
    }
  }
  UNION
  {
    SELECT ("From ID:" AS ?key) (?fromId AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsFrom/esco:NOCClassification ?fromId .
    }
    LIMIT 1
  }
  UNION
  {
    SELECT ("From version:" AS ?key) (?fromVersion AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsFrom/esco:NOCVersion ?fromVersion .
    }
    LIMIT 1
  }
  UNION
  {
    SELECT ("From type:" AS ?key) (?fromType AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:taxonomyFrom ?fromUri .
      ?fromUri esco:NOCConceptType ?fromType .
    }
  }
  UNION
  {
    SELECT ("To URI:" AS ?key) (?toUri AS ?value)
    WHERE
    {
      <%mappingEffort%> mp:taxonomyTo ?toUri .
    }
  }
  UNION
  {
    SELECT ("Language:" AS ?key) (?language AS ?value)
    WHERE
    {
      ?mapping a mp:Mapping ;
      mp:isMappingFor <%mappingEffort%> ;
      mp:mapsFrom/esco:referenceLanguage ?language .
    }
    LIMIT 1
  }
}
QUERY

allowed_formats = [
  SPARQL::Client::RESULT_CSV,
  SPARQL::Client::RESULT_TSV,
].freeze

get '/export' do
  # use a default format if not specified
  format = params[:format] || SPARQL::Client::RESULT_CSV
  uuid = params[:uuid]

  if uuid.nil?
    status 400
    body "Argument uuid is required"
    return
  end

  if !allowed_formats.any? {|x| x == format}
    status 400
    body "Not recognized format #{format}"
    return
  end

  mappingEffortCandidates = query(
    queryFindMappingEffort.gsub('%uuid%', uuid.sparql_escape))

  if mappingEffortCandidates.empty?
    status 404
    body "Can't find mapping effort #{uuid}"
    return
  end

  mappingEffort = mappingEffortCandidates.first[:mappingEffort].to_s

  isMappingFromEsco = query(
    queryIsMappingToNoc.gsub("%mappingEffort%", URI.escape(mappingEffort)))

  headersQuery = (
    if isMappingFromEsco
      queryFetchHeadersToNoc.gsub("%mappingEffort%", URI.escape(mappingEffort))
    else
      queryFetchHeadersFromNoc.gsub("%mappingEffort%", URI.escape(mappingEffort))
    end
  )

  responseHeaders = settings.sparql_client.response(headersQuery, {:content_type => format})
  headersLines = responseHeaders.body.lines.to_a

  if headersLines.count < 3
    raise "Can not determine headers for mapping effort #{mappingEffort}"
  end

  exportQuery = (
    if isMappingFromEsco
      queryFromEsco.gsub("%mappingEffort%", URI.escape(mappingEffort))
    else
      queryToEsco.gsub("%mappingEffort%", URI.escape(mappingEffort))
    end
  )

  response = settings.sparql_client.response(exportQuery, {:content_type => format})

  # return body of the response directly in the body
  headers "Content-Type" => response.header.content_type
  body headersLines[1..-1].join + response.body
end
