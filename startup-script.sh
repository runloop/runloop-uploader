#!/usr/bin/env bash

install_dependencies() {
  # update_apt
  install_email
}

update_apt() {
  sudo apt update
  sudo apt-get update
}

install_email() {
  local hostname
  # install the email client
  sudo apt-get install -y ssmtp
  # download the email credentials from Google Secrets Manager
  # this require the cloud-platform oauth access scope and Secret Manager Secret Accessor role on the service account
  sudo gcloud secrets versions access latest --secret=ssmtp_conf | sudo tee /etc/ssmtp/ssmtp.conf > /dev/null
  # get the hostname of this instance
  hostname=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/hostname)
  # append the hostname to the ssmpt.conf file on a new line
  echo -e "\nhostname=${hostname}" | sudo tee -a /etc/ssmtp/ssmtp.conf > /dev/null
}

delete_instance() {
  gcloud compute instances delete "$1" --zone=europe-west1-b --quiet
}

send_notification() {
  echo -e "Subject: Script complete\n\nThe script completed successfully" | ssmtp patsysgarden.cattv@gmail.com
}

main() {
  install_dependencies
  send_notification
  # delete_instance "$1"
}

main "$@"