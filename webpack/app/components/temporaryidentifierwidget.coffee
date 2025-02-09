import $ from "jquery"


class TemporaryIdentifierWidgetController

  constructor: ->
    console.debug "TemporaryIdentifierWidget::load"

    # placeholder that signals to create a new temporary identifier
    @auto_wildcard = "-- autogenerated --"
    @is_add_sample_form = document.body.classList.contains "template-ar_add"

    if @is_add_sample_form
        @reset_temporary_identifiers()

    # Bind event handlers
    $("body").on "change", ".TemporaryIdentifier input[type='checkbox']", @on_temporary_change
    # NOTE: custom events fired from QuerySelect widget!
    $("body").on "select", ".TemporaryIdentifier", @on_mrn_selected
    $("body").on "deselect", ".TemporaryIdentifier", @on_mrn_deselected
    $("body").on "select", "tr[fieldname=PatientID] textarea", @on_patient_id_selected

    return @

  ###
   * Reset all temporary identifiers
   *
   * Avoid that temporary IDs get copied
  ###
  reset_temporary_identifiers: () =>
    @debug "TemporaryIdentifierWidget::reset_temporary_identifiers"

    fields = document.querySelectorAll(".TemporaryIdentifier")
    fields.forEach (field, index) =>
      temporary = field.querySelector("input[name*='_temporary']")
      if not temporary.checked
        return

      # uncheck temporary
      temporary.checked = false

      # flush auto ID field
      auto_id_field = field.querySelector("input[name*='_value_auto']")
      @native_set_value auto_id_field, ""

      # reset ID field
      input_field = field.querySelector("textarea")
      @native_set_value input_field, ""

      # reset Patient ID
      @set_sibling_value field, "PatientID", ""


  ###
   * Set all patient related fields
  ###
  set_patient_data: (el, data) =>
    record = {
      "MedicalRecordNumber": "",
      "PatientFullName.firstname": "",
      "PatientFullName.lastname": "",
      "PatientAddress": "",
      "DateOfBirth.dob": "",
      "Age": "",
      "Sex": "",
      "Gender": "",
      "PatientID": "",
    }
    record = Object.assign(record, data)

    # Update field values from the whole form
    for field, value of record
      @set_sibling_value el, field, value


  on_temporary_change: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_temporary_change °°°"

    el = event.currentTarget
    fieldname = @get_field_name el

    # Is temporary?
    is_temporary = el.checked

    input_field = @get_input_element fieldname
    if is_temporary and not input_field.value
      @native_set_value input_field, @auto_wildcard
    else if !is_temporary and input_field.value == @auto_wildcard
      @native_set_value input_field, ""


  ###
   * Existing MRN removed
  ###
  on_mrn_deselected: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_mrn_deselected °°°"

    el = event.currentTarget
    fieldname = @get_field_name el

    # unset temporary checkbox
    temporary_checkbox = document.getElementById("#{fieldname}_temporary")
    temporary_checkbox.checked = false

    @set_patient_data el, {}


  ###
   * Existing MRN selected or new entered
  ###
  on_mrn_selected: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_mrn_selected °°°"

    el = event.currentTarget
    mrn = event.detail.value

    if mrn == @auto_wildcard
      return

    el = event.currentTarget

    # Search for an existing MRN
    @search_patient {patient_mrn:mrn}
    .done (data) =>
      return unless data

      # Generate a physical address line
      physical_address = data.address[0]
      address = [
        physical_address.address,
        physical_address.zip,
        physical_address.city,
        physical_address.country
      ].filter((value) -> value).join(", ")

      # Write back the physical address line for the template
      data.address_line = address

      # map patient fields -> Sample fields
      record = {
        "MedicalRecordNumber": data.mrn,
        "PatientFullName.firstname": data.firstname,
        "PatientFullName.lastname": data.lastname,
        "PatientAddress": address,
        "DateOfBirth.dob": @format_date(data.birthdate),
        "Age": data.age,
        "Sex": data.sex,
        "Gender": data.gender,
        "PatientID": data.patient_id,
        "review_state": data.review_state,
      }

      @set_patient_data el, record


  ###
   * Existing Patient ID selected or new entered
  ###
  on_patient_id_selected: (event) =>
    @debug "°°° TemporaryIdentifierWidget::on_patient_id_selected °°°"

    el = event.currentTarget
    patient_id = event.detail.value

    el = event.currentTarget

    # Search for an existing MRN
    @search_patient {patient_id:patient_id}
    .done (data) =>
      return unless data

      # Generate a physical address line
      physical_address = data.address[0]
      address = [
        physical_address.address,
        physical_address.zip,
        physical_address.city,
        physical_address.country
      ].filter((value) -> value).join(", ")

      # Write back the physical address line for the template
      data.address_line = address

      # map patient fields -> Sample fields
      record = {
        "MedicalRecordNumber": data.mrn,
        "PatientFullName.firstname": data.firstname,
        "PatientFullName.lastname": data.lastname,
        "PatientAddress": address,
        "DateOfBirth.dob": @format_date(data.birthdate),
        "Age": data.age,
        "Sex": data.sex,
        "Gender": data.gender,
        "PatientID": data.patient_id,
        "review_state": data.review_state,
      }

      @set_patient_data el, record


  ###
   * Returns the input element for manual introduction of an identifier value
  ###
  get_input_element: (field) =>
    document.querySelector("##{field} textarea")


  ###
   * Returns the field name the element belongs to
  ###
  get_field_name: (element) =>
    parent = element.closest("div[data-fieldname]")
    $(parent).attr "data-fieldname"


  ###
   * Returns the sibling field element with the specified name
  ###
  get_sibling: (element, name, subfield='') =>
    field = name
    if @is_add_sample_form
      parent = element.closest("td[arnum]")
      sample_num = $(parent).attr "arnum"
      field = name+'-'+sample_num

    selector = '[name="'+field+'"]'
    if subfield != ''
      field = field+'.'+subfield
      selector = '[name^="'+field+':"]'

    document.querySelector(selector)


  ###
   * Sets the value for an sibling field with specified base name
  ###
  set_sibling_value: (element, name, value) =>
    @debug "°°° TemporaryIdentifierWidget::set_sibling_value:name=#{ name },value=#{ value } °°°"
    subfield = ''
    if "." in name
      split = name.split "."
      name = split[0]
      subfield = split[1]

    field = @get_sibling element, name, subfield
    return unless field
    @debug ">>> #{ field.name } = #{ value } "
    @native_set_value field, value

  ###*
    * Set input value with native setter to support ReactJS components
  ###
  native_set_value: (input, value) =>
    # https://stackoverflow.com/questions/23892547/what-is-the-best-way-to-trigger-onchange-event-in-react-js
    # TL;DR: React library overrides input value setter

    setter = null
    if input.tagName == "TEXTAREA"
      setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set
    else if input.tagName == "SELECT"
      setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, "value").set
    else if input.tagName == "INPUT"
      setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set
    else
      input.value = value

    if setter
      setter.call(input, value)

    evt = new Event("input", {bubbles: true})
    input.dispatchEvent(evt)

  ###
   * Formats a date to yyyy-mm-dd
  ###
  format_date: (date_value) =>
    if not date_value?
      return ""
    d = new Date(date_value)
    out = [
      d.getFullYear(),
      ('0' + (d.getMonth() + 1)).slice(-2),
      ('0' + d.getDate()).slice(-2),
    ]
    out.join('-')

  ###
   * Search a patient with a specific query
   * Returns an object with information about the patient if found
  ###
  search_patient: (query) =>
    @debug "°°° TemporaryIdentifierWidget::search_patient °°°"

    # Grab the catalog name to search against
    catalog_name = document.querySelector('[name="config_catalog"]').value

    # Fields to include on search results
    fields = [
      "mrn"
      "patient_id"
      "firstname"
      "lastname"
      "age"
      "birthdate"
      "sex"
      "gender"
      "email"
      "address"
      "review_state"
    ]

    data =
      portal_type: "Patient"
      catalog_name: catalog_name
      include_fields: fields
      page_size: 1

    data = Object.assign(data, query)

    deferred = $.Deferred()
    options =
      url: @get_portal_url() + "/@@API/read"
      data: data

    @ajax_submit options
    .done (data) ->
      object = {}
      if data.objects
        # resolve with the first item of the list
        object = data.objects[0]
      return deferred.resolveWith this, [object]

    deferred.promise()


  ###
   * Ajax Submit with automatic event triggering and some sane defaults
  ###
  ajax_submit: (options={}) =>
    @debug "°°° TemporaryIdentifierWidget::ajax_submit °°°"

    # some sane option defaults
    options.type ?= "POST"
    options.url ?= @get_portal_url()
    options.context ?= this
    options.dataType ?= "json"
    options.data ?= {}
    options._authenticator ?= $("input[name='_authenticator']").val()

    console.debug ">>> ajax_submit::options=", options

    $(this).trigger "ajax:submit:start"
    done = ->
      $(this).trigger "ajax:submit:end"
    return $.ajax(options).done done


  ###
   * Returns the portal url (calculated in code)
  ###
  get_portal_url: =>
    url = $("input[name=portal_url]").val()
    return url or window.portal_url


  ###
   * Prints a debug message in console with this component name prefixed
  ###
  debug: (message) =>
    console.debug "[senaite.patient.temporary_identifier_widget] ", message


export default TemporaryIdentifierWidgetController
