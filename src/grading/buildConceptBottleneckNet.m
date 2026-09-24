function lgraph = buildConceptBottleneckNet(numConcepts)
% BUILDCONCEPTBOTTLENECKNET Defines the fused grading network architecture.
% Architecture: ResNet-50 backbone → strip classifier head → concat concept vector
%               → FC fusion layers → 5-class softmax (ICDR grades 0-4)
%
% Input:  numConcepts - length of the flat concept feature vector (default: 7)
% Output: lgraph      - layerGraph ready for trainNetwork

    if nargin < 1
        numConcepts = 7; % [maCount hmCount exArea cwsCount nvFlag nvdScore nveScore]
    end
    
    cfg = config();
    numClasses = length(cfg.classLabels); % 5 classes: ICDR 0-4

    % --- 1. Load pretrained ResNet-50 and strip the classification head ---
    baseNet = resnet50();
    lgraph = layerGraph(baseNet);

    % Remove the final pooling-through-output layers and replace with identity
    % The last convolutional output is 'activation_49_relu' → avg_pool → fc1000
    % We cut at the global average pooling output: 'avg_pool'
    layersToRemove = {'avg_pool', 'fc1000', 'fc1000_softmax', 'ClassificationLayer_fc1000'};
    for i = 1:length(layersToRemove)
        try
            lgraph = removeLayers(lgraph, layersToRemove{i});
        catch
            % Layer may not exist in some ResNet-50 variants
        end
    end

    % Add a global average pooling to reduce 16x16x2048 -> 1x1x2048 -> flatten to 2048
    lgraph = addLayers(lgraph, globalAveragePooling2dLayer('Name', 'gap_backbone'));
    lgraph = connectLayers(lgraph, 'activation_49_relu', 'gap_backbone');

    % Flatten backbone output to a vector
    lgraph = addLayers(lgraph, flattenLayer('Name', 'flatten_backbone'));
    lgraph = connectLayers(lgraph, 'gap_backbone', 'flatten_backbone');

    % --- 2. Concept input branch ---
    % A separate featureInputLayer accepts the concept vector at inference time
    conceptBranch = [
        featureInputLayer(numConcepts, 'Name', 'concept_input', 'Normalization', 'zscore')
        fullyConnectedLayer(32, 'Name', 'concept_fc1')
        batchNormalizationLayer('Name', 'concept_bn1')
        reluLayer('Name', 'concept_relu1')
        fullyConnectedLayer(16, 'Name', 'concept_fc2')
        reluLayer('Name', 'concept_relu2')
    ];
    lgraph = addLayers(lgraph, conceptBranch);

    % --- 3. Fusion head: concat backbone embedding + concept branch ---
    fusionLayers = [
        concatenationLayer(1, 2, 'Name', 'fusion_concat')   % concat along feature dim
        fullyConnectedLayer(256, 'Name', 'fusion_fc1')
        batchNormalizationLayer('Name', 'fusion_bn1')
        reluLayer('Name', 'fusion_relu1')
        dropoutLayer(0.4, 'Name', 'fusion_dropout')
        fullyConnectedLayer(numClasses, 'Name', 'grade_fc')
        softmaxLayer('Name', 'grade_softmax')
        classificationLayer('Name', 'grade_output')
    ];
    lgraph = addLayers(lgraph, fusionLayers);

    % Wire up: backbone → concat input 1; concept branch → concat input 2
    lgraph = connectLayers(lgraph, 'flatten_backbone', 'fusion_concat/in1');
    lgraph = connectLayers(lgraph, 'concept_relu2',    'fusion_concat/in2');
end
