package compose

import (
	"strings"
	"guku.io/devx"
	"guku.io/devx/traits"
)

#ComposeManifest: {
	devx.#Component
	$guku: component: "ComposeManifest"

	version: string | *"3"
	volumes: [string]: null
	services: [string]: {
		image: string
		depends_on?: [...string]
		ports?: [...string]
		environment?: [string]: string
		command?: string
		volumes?: [...string]
	}
}

#ComposeService: devx.#Transformer & {
	$guku: transformer: "ComposeService"

	input: {
		component: {
			devx.#Component
			traits.#Workload
			traits.#Replicable
			traits.#Exposable
			...
		}
		context: {
			dependencies: [...string]
		}
	}

	feedforward: components: compose: #ComposeManifest & {
		services: "\(input.component.$guku.id)": {
			image: input.component.image
			ports: [
				for p in input.component.ports {
					"\(p.port):\(p.target)"
				},
			]
			environment: input.component.env
			depends_on:  input.context.dependencies
			volumes: [
				for v in input.component.volumes {
					if v.readOnly {
						"\(v.source):\(v.target):ro"
					}
					if !v.readOnly {
						"\(v.source):\(v.target)"
					}
				},
			]
		}
		for v in input.component.volumes {
			if !strings.HasPrefix(v.source, ".") && !strings.HasPrefix(v.source, "/") {
				volumes: "\(v.source)": null
			}
		}
	}

	feedback: component: {
		host: "\(input.component.$guku.id)"
	}

}

#ComposePostgresDB: devx.#Transformer & {
	$guku: transformer: "ComposePostgresDB"

	input: {
		component: {
			devx.#Component
			traits.#Postgres
			...
		}
		context: {
			dependencies: [...string]
		}
	}

	feedforward: components: {
		compose: #ComposeManifest & {
			_username: string @guku(generate)
			_password: string @guku(generate,secret)
			services: "\(input.component.$guku.id)": {
				image: "postgres:\(input.component.version)-alpine"
				ports: [
					"\(input.component.port)",
				]
				if input.component.persistent {
					volumes: [
						"pg-data:/var/lib/postgresql/data",
					]
				}
				environment: {
					POSTGRES_USER:     _username
					POSTGRES_PASSWORD: _password
					POSTGRES_DB:       input.component.database
				}
				depends_on: input.context.dependencies
			}
			if input.component.persistent {
				volumes: "pg-data": null
			}
		}
	}

	feedback: component: {
		host:     "\(input.component.$guku.id)"
		username: feedforward.components.compose._username
		password: feedforward.components.compose._password
	}
}

#ComposeMysqlDB: devx.#Transformer & {
	$guku: transformer: "ComposeMysqlDB"

	input: {
		component: {
			devx.#Component
			traits.#Mysql
			...
		}
		context: {
			dependencies: [...string]
		}
	}

	feedforward: components: {
		compose: #ComposeManifest & {
			_username: string @guku(generate)
			_password: string @guku(generate,secret)
			services: "\(input.component.$guku.id)": {
				image: "mysql:\(input.component.version)"
				ports: [
					"\(input.component.port)",
				]
				if input.component.persistent {
					volumes: [
						"mysql-data:/var/lib/mysql",
					]
				}
				environment: {
					MYSQL_ROOT_PASSWORD: _password
					MYSQL_USER:          _username
					MYSQL_PASSWORD:      _password
					MYSQL_DATABASE:      input.component.database
				}
				depends_on: input.context.dependencies
			}
			if input.component.persistent {
				volumes: "mysql-data": null
			}
		}
	}

	feedback: component: {
		host:     "\(input.component.$guku.id)"
		username: feedforward.components.compose._username
		password: feedforward.components.compose._password
	}
}