import { Controller } from "stimulus"
import { DatasetAPI } from "../utils/dataset_api"
import {SearchAPI} from "../utils/search_api"

export default class extends Controller {
    static targets = [  ]
    static values = {  }

    connect() {
        $("#random_sample").on("click", event => {
            SearchAPI.random_sample( data => {
                $("#random_sample_offcanvas .offcanvas-body").html(data["content"])
            })
        })
    }

    toggleResultSelection(event){
        if(!['A', 'IMG'].includes(event.target.tagName)) {
            $(event.target).parents("div.search_result").toggleClass("selected")
        }
    }

    selectWorkingDataset(event) {
        const datasetID = parseInt($(event.target).find("option:selected").val())
        DatasetAPI.setCurrentWorkingDataset(datasetID, (data) => {})
    }

    addSelectedDocumentsToWorkingDataset(event) {
        const documentsIds = $(".search_result.selected").map((index, document) => {
            return document.getAttribute("data-doc-id")
        }).get()
        DatasetAPI.addSelectedDocumentsToWorkingDataset(documentsIds, (data)=> {
            $("#notifications").append(data['notif'])
            for(const notif of $('.toast')) {
                const notifToast = bootstrap.Toast.getOrCreateInstance(notif)
                notifToast.show()
                notif.addEventListener('hidden.bs.toast', (event) => {
                    bootstrap.Toast.getOrCreateInstance(event.target).dispose()
                    event.target.remove()
                })
            }

            // Find dataset in list and change nb docs
            const option = $("#working_dataset_select").find(":selected")
            option.html(`${data['title']} (${data['nbdocs']} docs)`)

            //unselect all docs
            $("div.search_result").removeClass("selected")

            //Add dataset pill under selected documents
            for(const doc_id of Object.keys(data['results_datasets'])) {
                $(`.search_result[data-doc-id=\"${doc_id}\"] .in_datasets`).html(data['results_datasets'][doc_id])
            }
        })
    }

    addAllDocumentsToWorkingDataset(event) {
        const params = JSON.parse($(event.target).attr('data-search-params'))
        DatasetAPI.addAllDocumentsToWorkingDataset(params, (data) => {
            $("#notifications").append(data)
            for(const notif of $('.toast')) {
                const notifToast = bootstrap.Toast.getOrCreateInstance(notif)
                notifToast.show()
                notif.addEventListener('hidden.bs.toast', (event) => {
                    bootstrap.Toast.getOrCreateInstance(event.target).dispose()
                    event.target.remove()
                })
            }
        })
    }

}