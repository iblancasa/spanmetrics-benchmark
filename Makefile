.PHONY: start-cluster
start-cluster:
	kind create cluster --name spanmetrics-test
	helm repo add coralogix https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
	helm repo update
	echo "<WARNING> Create the coralogix-keys in the cluster before anything else"

.PHONY: clean
clean:
	kind delete cluster --name spanmetrics-test

.PHONY: install-collector
install-collector:
	helm upgrade \
		--install otel-coralogix-integration \
		coralogix/otel-integration \
		--version=0.0.158 \
		--render-subchart-notes \
		--set global.domain="eu2.coralogix.com" \
		--set global.clusterName="spanmetrics-test"

.PHONY: install-collector-with-spanmetrics
install-collector-with-spanmetrics:
	helm upgrade \
		--install otel-coralogix-integration \
		coralogix/otel-integration \
		--version=0.0.158 \
		--render-subchart-notes \
		--set global.domain="eu2.coralogix.com" \
		--set global.clusterName="spanmetrics-test" \
		--set opentelemetry-agent.presets.spanMetrics.enabled=true
	
.PHONY: install-collector-with-preset-spanmetrics
install-collector-with-preset-spanmetrics:
	helm upgrade \
		--install otel-coralogix-integration \
		coralogix/otel-integration \
		--version=0.0.158 \
		--render-subchart-notes \
		--set global.domain="eu2.coralogix.com" \
		--set global.clusterName="spanmetrics-test" \
		--file values.yaml

.PHONY: install-telemetrygen
install-telemetrygen:
	kubectl delete -f telemetrygen.yaml || true
	kubectl apply -f telemetrygen.yaml
