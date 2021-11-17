FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install rpm -y

COPY Fortify_SCA_and_Apps_20.2.2_linux_x64.run /tmp
COPY fortify.license /tmp
COPY installerSettings /tmp

RUN chmod +x /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run && \
    /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run --mode unattended --optionfile /tmp/installerSettings && \
    /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/bin/fortifyupdate && \
    rm /tmp/Fortify_SCA_and_Apps_20.2.2_linux_x64.run /tmp/fortify.license /tmp/installerSettings

RUN rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/worker.properties && \
    ln -s /sastsensorsecrets/worker.properties \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/ && \
	rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/scancentral.properties && \
    ln -s /sastsensorsecrets/scancentral.properties \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/Core/config/ && \
    rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/jre/lib/security/cacerts && \
    ln -s /sastsensorsecrets/cacerts \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/jre/lib/security/ && \
    rm -f /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/fortify.license && \
	ln -s /sastsensorsecrets/fortify.license \
	          /opt/Fortify/Fortify_SCA_and_Apps_20.2.2/

CMD ["/opt/Fortify/Fortify_SCA_and_Apps_20.2.2/bin/scancentral", "worker"]
