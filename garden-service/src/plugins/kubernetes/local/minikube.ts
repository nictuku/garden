/*
 * Copyright (C) 2018 Garden Technologies, Inc. <info@garden.io>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import * as execa from "execa"

/**
 * Automatically set docker environment variables for minikube
 * TODO: it would be better to explicitly provide those to docker instead of using process.env
 */
export async function setMinikubeDockerEnv() {
  let minikubeEnv: string

  try {
    minikubeEnv = (await execa("minikube", ["docker-env", "--shell=bash"])).stdout
  } catch (err) {
    if ((<execa.ExecaError>err).stderr.includes("driver does not support")) {
      return
    }
    throw err
  }

  for (const line of minikubeEnv.split("\n")) {
    const matched = line.match(/^export (\w+)="(.+)"$/)
    if (matched) {
      process.env[matched[1]] = matched[2]
    }
  }
}
