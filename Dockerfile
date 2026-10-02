FROM eclipse-temurin:21.0.12_8-jdk-noble

COPY target/cake-service-0.0.1-SNAPSHOT.jar cake-service.jar

EXPOSE 8081
ENTRYPOINT ["java","-jar","/cake-service.jar"]

