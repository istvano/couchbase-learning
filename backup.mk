.PHONY: backup/test
backup/test: ##@backup Get info
	$(CURL) --insecure -X PUT $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/backup \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		--header ‘Content-Type: application/json’ \
			--data ‘{  
			    “version”: “1",  
			    “users”: [  
			        {  
			            “id”: “akhil”,  
			            “domain”: “local”,  
			            “groups”: [],  
			            “roles”: [  
			                “ro_admin”  
			            ],  
			            “auth”: {  
			                “hash”: {  
			                    “hashes”: [  
			                        “1DiMNufuRiOwSCdnYL+yRWfM52V01XSWmAfIAbeOSrY=”  
			                    ],  
			                    “algorithm”: “argon2id”,  
			                    “salt”: “93AvPQwGaGnpeOeWrZHIMg==“,  
			                    “parallelism”: 1,  
			                    “time”: 3,  
			                    “memory”: 524288  
			                },  
			                “scram-sha-512": {  
			                    “salt”: “73mcDEhyezds/i8CqvJfDHTCEMApvMu+M3P+7klKfk3MfWi2uFiyoGOWIh97H4bl9Gd28Zi6j3IaPQCPIA70BA==“,  
			                    “iterations”: 15000,  
			                    “hashes”: [  
			                        {  
			                            “stored_key”: “NSmd8FVtg7k+RUUUBRK4DdGJHILP4jAp0fRYqro7TLNaMsqU62R7PJfnR0O5eBKVoDmnVEjfuFMxYsGe9beN5Q==“,  
			                            “server_key”: “SYRJt9wPxWF2NVB+EghJOa8ET6e5D1g6hZyLurbR6dHYWiq3RmZx3QJ5BBi8YvkXPfYalAvcmIRtGrr3LzCHJA==”  
			                        }  
			                    ]  
			                },  
			                “scram-sha-256”: {  
			                    “salt”: “HjO/g1ryyUKY5V2lm3DMvs6tbvjHDaA8m1lTR130nf8=“,  
			                    “iterations”: 15000,  
			                    “hashes”: [  
			                        {  
			                            “stored_key”: “Llb9BCzpYq90TYQKTw3qNgScZdKi6x+JxoUgz3C3yPc=“,  
			                            “server_key”: “A1MzKarhxQ1M4Qj6HUfcsIQqa3aJjnBnWOj/+TMcq+E=”  
			                        }  
			                    ]  
			                },  
			                “scram-sha-1”: {  
			                    “salt”: “0fjzUEX9EEB/H6D5jSs/mP43RsM=“,  
			                    “iterations”: 15000,  
			                    “hashes”: [  
			                        {  
			                            “stored_key”: “ZwFe5j3QkvV52MPb32qbKO7ym/U=“,  
			                            “server_key”: “6y5IRYByRjDAW0V5b933vzyfnAk=”  
			                        }  
			                    ]  
			                }  
			            }  
			        },  
			    ],  
			    “groups”: []  
			}’ \
    	-d canOverwrite=false


