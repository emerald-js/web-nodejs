import {Provider} from '@emerald-js/core'
import {add, value} from '@emerald-js/container'
import Koa from 'koa'
import Router from 'koa-router'

export default class Web extends Provider
	@register: (c) ->
		c.configure
			'web.koa': (c) ->
				koa = new Koa
				router = await c.get 'web.router'
				koa.use router.routes()
				koa.use router.allowedMethods()

				koa

			'web.router': -> new Router
			routes: add()


	boot: ->
		@mountRoutes()

	listen: (port) ->
		koa = await @getKoa()

		if port is undefined and @c.has 'config'
			config = await @c.get 'config'
			port = config?.http?.port?

		if not port
			port = 8888

		koa.listen port

	getKoa: ->
		await @c.get 'web.koa'

	mountRoutes: ->
		routes = await @c.get 'routes'
		router = await @c.get 'web.router'

		wrap = (action) =>
			if typeof action == 'function' then action else (ctx, next) =>
				handler = await @c.get action

				if typeof handler == 'function'
					handler ctx, next
				else if 'handle' of handler and typeof handler.handle == 'function'
					handler.handle ctx, next
				else
					throw new Error 'handler should be an object with a function handle, or a function'

		proxy =
			route: (verb, path, action) ->
				router[verb] path, wrap action

			use: (path, ...args) ->
				router.use path, args.map (a) -> wrap a


		for verb in ['get', 'del', 'post', 'head', 'patch', 'delete', 'put']
			_ = (verb) =>
				proxy[verb] = (path, action) ->
					proxy.route verb, path, action

			_ verb

		for route in routes
			route proxy, @c
