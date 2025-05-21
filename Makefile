PHONY: build deploy

build:
	@echo "Building the project..."
	@echo "This is a placeholder for the build process."
	docker build -t europe-docker.pkg.dev/filiplindqvist-com-ea66d/images/garmin-fetch:latest .

deploy: build
	gcloud auth configure-docker europe-docker.pkg.dev
	docker push europe-docker.pkg.dev/filiplindqvist-com-ea66d/images/garmin-fetch:latest

