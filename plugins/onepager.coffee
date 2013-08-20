module.exports = (env, callback) ->

  utils = env.utils
  path  = require 'path'
  _     = require 'underscore'

  page            = env.plugins.MarkdownPage
  ContentTree     = env.ContentTree
  ContentPlugin   = env.ContentPlugin

  nest = (tree) ->
    ### Return all the items in the *tree* as an array of content plugins. ###
    index = tree[ 'index.md' ]
    index.topics = []
    for key, value of tree
      if key == 'index.md'
        # skip
      else if value instanceof ContentTree
        index.topics.push nest value
      else if value instanceof ContentPlugin
        index.topics.push value
      else
        # skip
    return index

  onePagerView = (env, locals, contents, templates, callback) ->
    ### Behaves like templateView but allso adds topics to the context ###

    if @template == 'none'
      return callback null, null

    template = templates[@template]
    if not template?
      callback new Error "page '#{ @filename }' specifies unknown template '#{ @template }'"
      return

    @setTopics()

    ctx =
      env: env
      page: this
      contents: contents
      breadcrumbs: @getBreadcrumbs( contents )

    env.utils.extend ctx, locals

    template.render ctx, callback

  class OnePagerPage extends page
    directory: null
    topics: []

    constructor: ( @filepath, @metadata, @markdown ) ->
      @directory = path.dirname( @filepath.full )

    getView: -> 'onepager'

    setTopics: ->
      ContentTree.fromDirectory env, @directory, ( err, tree ) =>
        tree = nest tree
        @topics = tree.topics

    @property 'description', 'getDescription'
    getDescription: ->
      if @metadata.description then @metadata.description

    @property 'arguments', 'getArguments'
    getArguments: ->
      if @metadata.arguments then @metadata.arguments

    @property 'argument_names', 'getArgumentNames'
    getArgumentNames: ->
      args = @getArguments()
      result = ""
      if args
        result = "( "
        i = 0
        console.log args.length
        for key, value of args
          i = i + 1
          result += key
          if i != Object.keys(args).length
            result += ", "
        result += " )"
      return result

    @property 'api_url', 'getAPIUrl'
    getAPIUrl: ->
      if @metadata.api_url then @metadata.api_url

    getBreadcrumbs: ( tree ) ->
      items = []
      item = path.dirname @filepath.relative
      while item != '.'
        items.push "/#{item}/"
        item = path.dirname item
      items.push '/'
      items.reverse()
      flat = ContentTree.flatten( tree )
      items = _.map( items, ( url ) ->
        filtered = flat.filter (page) ->
          matched = page.getUrl() == url
          if matched then page.last = false
          return matched
        return filtered[0]
        )
      items[ items.length - 1 ].last = true
      return items

  OnePagerPage.fromFile = (args...) ->
    page.fromFile.apply(this, args)

  env.helpers.breadcrumbText = ( page ) ->
    console.log page.metadata
    if page.metadata && page.metadata.breadcrumb
      page.metadata.breadcrumb
    else
      page.metadata.title

  env.registerContentPlugin 'cheatsheet', 'cheatsheet/**', OnePagerPage

  # register the template view used by the page plugin
  env.registerView 'onepager', onePagerView

  env.registerGenerator 'onepager', (contents, callback) ->
    callback null, contents

  callback()