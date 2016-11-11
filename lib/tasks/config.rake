namespace :config do
  desc 'Generates a configuration file for the current Rails environment'

  PLATE_PURPOSES = [
    'ILC Stock',
    'ILC AL Libs',
    'ILC Lib PCR',
    'ILC Lib PCR-XP',
    'ILC AL Libs Tagged',
    'ILC Lib Chromium'
  ]

  QC_PLATE_PURPOSES = [

  ]

  TUBE_PURPOSES = [
    'ILC Lib Pool Norm'
  ]

  QC_TUBE_PURPOSES = [
    'ILC QC Pool'
  ]

  task :generate => :environment do
    api = Sequencescape::Api.new(IlluminaCPipeline::Application.config.api_connection_options)
    plate_purposes    = api.plate_purpose.all.select { |pp| PLATE_PURPOSES.include?(pp.name) }
    qc_plate_purposes = api.plate_purpose.all.select { |pp| QC_PLATE_PURPOSES.include?(pp.name) }
    tube_purposes     = api.tube_purpose.all.select  { |tp| TUBE_PURPOSES.include?(tp.name)  }
    qc_tube_purposes  = api.tube_purpose.all.select  { |tp| QC_TUBE_PURPOSES.include?(tp.name)  }

    barcode_printer_uuid = lambda do |printers|
      ->(printer_name){
        printers.detect { |prt| prt.name == printer_name}.try(:uuid) or
        raise "Printer #{printer_name}: not found!"
      }
    end.(api.barcode_printer.all)

    CONFIG = {}.tap do |configuration|

       configuration[:tag_groups] = [].tap do |tag_groups|
         puts "Preparing tag_groups ..."
         api.tag_group.each do |tag_group|
           tag_groups << {
             :uuid => tag_group.uuid,
             :name => tag_group.name,
             :tags_keys => tag_group.tags.keys.map(&:to_i).sort
           }
         end
       end


      configuration[:'large_insert_limit'] = 250

      configuration[:searches] = {}.tap do |searches|
        puts "Preparing searches ..."

        api.search.all.each do |search|
          searches[search.name] = search.uuid
        end
      end

      configuration[:transfer_templates] = {}.tap do |transfer_templates|
        puts "Preparing transfer templates ..."

        api.transfer_template.all.each do |transfer_template|
          transfer_templates[transfer_template.name] = transfer_template.uuid
        end
      end

      configuration[:purposes] = {}.tap do |labware_purposes|
        # Setup a hash that will enable us to lookup the form, presenter, and state changing classes
        # based on the name of the plate purpose.  We can then use that to generate the information for
        # the mapping from UUID.

        # :form_class
        # The class used to create a plate: Form::CreationForm is a direct stamp and immediate redirect

        # :presenter_class
        # The class used to display a plate. Mainly determines which tabs are shown

        # state_changer_class
        # The class created on state change. Can perform additional actions

        # :default_printer_uuid
        # The uuid of the default printer.
        # Use eg. barcode_printer_uuid.('h105bc2') to lookup by name

        # :tag_layout_templates [Optional]
        # Used by tagging form. Filters list in drop down.
        # Shows all if empty or not specified.

        # :tags_per_well [Optional]
        # Used by tagging form.  Determines values of tags per
        # well dropdown/fixed field. Defaults to 1 if not defined.

        # :walking_by [Optional]
        # Filter the available walking by options.
        # default: ['manual by plate', 'manual by pool', 'wells of plate']

        #
        # The inner block is laid out so that the class names align, not so it's readable!
        name_to_details = Hash.new do |h,k|
          # The default values
          h[k] = {
            :form_class           => 'Forms::CreationForm',
            :presenter_class      => 'Presenters::StandardPresenter',
            :state_changer_class  => 'StateChangers::DefaultStateChanger',
            :default_printer_uuid => barcode_printer_uuid.('h105bc2')
          }
        end.tap do |presenters|
          # Illumina-C plates
          presenters['ILC Stock'].merge!(
            :presenter_class      => 'Presenters::StockPlatePresenter'
          )
          presenters['ILC AL Libs'].merge!(
            :presenter_class      => 'Presenters::AlLibsPlatePresenter'
          )
          presenters['ILC Lib PCR'].merge!(
            :form_class           => 'Forms::TaggingForm',
            :presenter_class      => 'Presenters::TaggedPresenter'
          )
          presenters['ILC Lib PCR-XP'].merge!(
            :state_changer_class  => 'StateChangers::PlateToTubeStateChanger',
            :presenter_class      => 'Presenters::FinalPlatePresenter'
          )
          presenters['ILC AL Libs Tagged'].merge!(
            :state_changer_class  => 'StateChangers::PlateToTubeStateChanger',
            :form_class           => 'Forms::TaggingForm',
            :presenter_class      => 'Presenters::QCTaggedPresenter'
          )
          presenters['ILC Lib Chromium'].merge!(
            :state_changer_class  => 'StateChangers::PlateToTubeStateChanger',
            :form_class           => 'Forms::TaggingForm',
            :tag_layout_templates => [
              'Chromium Genome 96',
              'Chromium Single Cell'
             ],
            :presenter_class      => 'Presenters::QCTaggedPresenter',
            :tags_per_well        => [4],
            :walking_by           => ['as group by plate']
          )
          presenters['ILC Lib Pool Norm'].merge!(
            :form_class           => 'Forms::TubesForm',
            :presenter_class      => 'Presenters::FinalTubePresenter',
            :default_printer_uuid => barcode_printer_uuid.('h105bc2')
          )
          presenters['ILC QC Pool'].merge!(
            :form_class           => 'Forms::PooledTubesForm',
            :presenter_class      => 'Presenters::QCTubePresenter',
            :state_changer_class  => 'StateChangers::QcTubeStateChanger',
            :default_printer_uuid => barcode_printer_uuid.('h105bc')
          )

        end

        purpose_details_by_uuid = lambda { |labware_purposes, purpose|
          labware_purposes[purpose.uuid] = name_to_details[purpose.name].dup.merge(
            :name => purpose.name
          )
        }.curry.(labware_purposes)

        puts "Preparing plate purpose forms, presenters, and state changers ..."
        plate_purposes.each(&purpose_details_by_uuid)
        puts "Preparing QC plate purpose forms, presenters, and state changers ..."
        qc_plate_purposes.each(&purpose_details_by_uuid)

        puts "Preparing Tube purpose forms, presenters, and state changers ..."
        tube_purposes.each(&purpose_details_by_uuid)
        puts "Preparing QC Tube purpose forms, presenters, and state changers ..."
        qc_tube_purposes.each(&purpose_details_by_uuid)
      end

      configuration[:request_types] = {}.tap do |request_types|
        # Array is [child_purpose,poolable]
        # poolable: automatically pool tubes on qc_complete.
        request_types['Illumina-C Library Creation PCR']    = ['ILC AL Libs',true]
        request_types['Illumina-C Library Creation PCR No Pooling']    = ['ILC AL Libs',false]
        request_types['Illumina-C Library Creation No PCR'] = ['ILC AL Libs Tagged',true]
        request_types['Illumina-C Library Creation No PCR No Pooling'] = ['ILC AL Libs Tagged',false]
        request_types['Illumina-C Chromium library creation'] = ['ILC Lib Chromium',true]
      end


      configuration[:purpose_uuids] = {}.tap do |purpose_uuids|

        store_purpose_uuids = lambda { |purpose_uuids, purpose|
          purpose_uuids[purpose.name] = purpose.uuid
        }.curry.(purpose_uuids)

        tube_purposes.each(&store_purpose_uuids)
        plate_purposes.each(&store_purpose_uuids)
        qc_plate_purposes.each(&store_purpose_uuids)
      end

      configuration[:qc_purposes] = QC_TUBE_PURPOSES

      configuration[:submission_templates] = {}.tap do |submission_templates|
        puts "Preparing submission templates..."
        submission_templates['miseq']= api.order_template.all.detect {|ot| ot.name==IlluminaCPipeline::Application.config.qc_submission_name }.uuid
      end

      puts "Setting study..."
      configuration[:study] = IlluminaCPipeline::Application.config.study_uuid||
        puts("No study specified, using first study")||
        api.study.first.uuid
      puts "Setting project..."
      configuration[:project] = IlluminaCPipeline::Application.config.project_uuid||
        puts("No project specified, using first project")||
        api.project.first.uuid

      configuration[:printers] = {}.tap do |printers|
        printers['limit'] = 5
        printers['default_count'] = 2
      end

      configuration[:metadata_key_options] = [
        'example 1',
        'example 2',
        'example 3',
        'example 4'
      ]

    end


    # Write out the current environment configuration file
    File.open(File.join(Rails.root, %w{config settings}, "#{Rails.env}.yml"), 'w') do |file|
      file.puts(CONFIG.to_yaml)
    end
  end

  task :default => :generate
end
